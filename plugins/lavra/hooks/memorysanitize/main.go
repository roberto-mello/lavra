package main

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

var (
	pathRE           = regexp.MustCompile(`(?:^|[` + "`" + `(\s])((?:[A-Za-z0-9_.-]+/)+[A-Za-z0-9_.-]+\.[A-Za-z0-9_-]+)`)
	backtickSymbolRE = regexp.MustCompile("`([A-Za-z_][A-Za-z0-9_]{2,})`")
	callSymbolRE     = regexp.MustCompile(`\b([A-Za-z_][A-Za-z0-9_]{2,})\(`)
	commandTrimRE1   = regexp.MustCompile(`"\s*(2>&1|\|\||&&|\||;).*$`)
	commandTrimRE2   = regexp.MustCompile(`\s+(2>&1|\|\||&&|\||;).*$`)
	whitespaceRE     = regexp.MustCompile(`\s+`)
	nonAlnumRE       = regexp.MustCompile(`[^a-z0-9]+`)
	noiseCommandRE   = regexp.MustCompile(`^(bd|git|bash|cat|echo|for|if)\s`)
	noiseTagRE       = regexp.MustCompile(`^<[^>]+>$`)
)

type config struct {
	knowledgeFile string
	archiveFile   string
	activeFile    string
	auditFile     string
	projectRoot   string
	timestamp     int64
}

type entry = map[string]any

type auditRecord map[string]any

type localAnchors struct {
	Files         []string `json:"files"`
	Symbols       []string `json:"symbols"`
	ExistingFiles []string `json:"existing_files"`
	MissingFiles  []string `json:"missing_files"`
}

type sanitizer struct {
	cfg         config
	summary     map[string]int
	audit       []auditRecord
	symbolCache map[string]bool
}

func main() {
	cfg, err := parseConfig()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	if err := run(cfg); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func parseConfig() (config, error) {
	var cfg config
	flag.StringVar(&cfg.knowledgeFile, "knowledge-file", "", "Path to knowledge.jsonl")
	flag.StringVar(&cfg.archiveFile, "archive-file", "", "Path to knowledge.archive.jsonl")
	flag.StringVar(&cfg.activeFile, "active-file", "", "Path to output knowledge.active.jsonl")
	flag.StringVar(&cfg.auditFile, "audit-file", "", "Path to output knowledge.audit.jsonl")
	flag.StringVar(&cfg.projectRoot, "project-root", "", "Project root used for anchor validation")
	flag.Parse()

	if cfg.knowledgeFile == "" || cfg.activeFile == "" || cfg.auditFile == "" {
		return config{}, errors.New("knowledge-file, active-file, and audit-file are required")
	}
	cfg.timestamp = time.Now().Unix()
	if cfg.projectRoot != "" {
		realRoot, err := filepath.EvalSymlinks(cfg.projectRoot)
		if err == nil {
			cfg.projectRoot = realRoot
		}
	}
	return cfg, nil
}

func run(cfg config) error {
	s := sanitizer{
		cfg: cfg,
		summary: map[string]int{
			"invalid_json":      0,
			"filtered_noise":    0,
			"duplicate_key":     0,
			"duplicate_content": 0,
			"stale_candidate":   0,
			"needs_review":      0,
			"active":            0,
		},
		symbolCache: make(map[string]bool),
	}

	entries, err := s.collectEntries()
	if err != nil {
		return err
	}

	activeEntries, err := s.buildActiveEntries(entries)
	if err != nil {
		return err
	}

	s.audit = append(s.audit, auditRecord{
		"ts":     cfg.timestamp,
		"action": "summary",
		"summary": map[string]int{
			"invalid_json":      s.summary["invalid_json"],
			"filtered_noise":    s.summary["filtered_noise"],
			"duplicate_key":     s.summary["duplicate_key"],
			"duplicate_content": s.summary["duplicate_content"],
			"stale_candidate":   s.summary["stale_candidate"],
			"needs_review":      s.summary["needs_review"],
			"active":            s.summary["active"],
		},
	})

	if err := writeJSONLines(cfg.activeFile, activeEntries); err != nil {
		return err
	}
	if err := writeJSONLines(cfg.auditFile, s.audit); err != nil {
		return err
	}
	return nil
}

func (s *sanitizer) collectEntries() ([]entry, error) {
	type source struct {
		name string
		path string
	}

	var sources []source
	if s.cfg.archiveFile != "" && fileExists(s.cfg.archiveFile) {
		sources = append(sources, source{name: "archive", path: s.cfg.archiveFile})
	}
	if fileExists(s.cfg.knowledgeFile) {
		sources = append(sources, source{name: "raw", path: s.cfg.knowledgeFile})
	}

	var valid []entry
	for _, src := range sources {
		file, err := os.Open(src.path)
		if err != nil {
			return nil, fmt.Errorf("open %s: %w", src.path, err)
		}

		scanner := bufio.NewScanner(file)
		buf := make([]byte, 0, 64*1024)
		scanner.Buffer(buf, 1024*1024)

		lineNo := 0
		for scanner.Scan() {
			lineNo++
			line := scanner.Text()
			if line == "" {
				continue
			}

			var obj map[string]any
			if err := json.Unmarshal([]byte(line), &obj); err != nil {
				s.summary["invalid_json"]++
				s.audit = append(s.audit, auditRecord{
					"ts":     s.cfg.timestamp,
					"action": "skip_invalid_json",
					"source": src.name,
					"line":   lineNo,
					"reason": "invalid_json",
				})
				continue
			}

			key := stringValue(obj["key"])
			content := normalizeText(stringValue(obj["content"]))
			if key == "" || content == "" {
				continue
			}
			if isNoisy(content) {
				s.summary["filtered_noise"]++
				s.audit = append(s.audit, auditRecord{
					"ts":     s.cfg.timestamp,
					"action": "filter_noise",
					"key":    key,
					"source": src.name,
					"reason": "command_like_content",
				})
				continue
			}

			obj["content"] = content
			valid = append(valid, obj)
		}

		if err := scanner.Err(); err != nil {
			if closeErr := file.Close(); closeErr != nil {
				return nil, fmt.Errorf("scan %s: %w (close: %v)", src.path, err, closeErr)
			}
			return nil, fmt.Errorf("scan %s: %w", src.path, err)
		}
		if err := file.Close(); err != nil {
			return nil, fmt.Errorf("close %s: %w", src.path, err)
		}
	}

	sort.Slice(valid, func(i, j int) bool {
		return tsValue(valid[i]) > tsValue(valid[j])
	})

	byKey := make(map[string]entry)
	deduped := make([]entry, 0, len(valid))
	for _, item := range valid {
		lowerKey := strings.ToLower(stringValue(item["key"]))
		if kept, ok := byKey[lowerKey]; ok {
			s.summary["duplicate_key"]++
			s.audit = append(s.audit, auditRecord{
				"ts":       s.cfg.timestamp,
				"action":   "dedupe_key",
				"key":      stringValue(item["key"]),
				"kept_key": stringValue(kept["key"]),
				"reason":   "duplicate_key",
			})
			continue
		}
		byKey[lowerKey] = item
		deduped = append(deduped, item)
	}

	byContent := make(map[string]entry)
	finalEntries := make([]entry, 0, len(deduped))
	for _, item := range deduped {
		contentKey := strings.ToLower(stringValue(item["type"])) + "|" + canonicalText(stringValue(item["content"]))
		if kept, ok := byContent[contentKey]; ok {
			s.summary["duplicate_content"]++
			s.audit = append(s.audit, auditRecord{
				"ts":       s.cfg.timestamp,
				"action":   "dedupe_content",
				"key":      stringValue(item["key"]),
				"kept_key": stringValue(kept["key"]),
				"reason":   "duplicate_content",
			})
			continue
		}
		byContent[contentKey] = item
		finalEntries = append(finalEntries, item)
	}

	sort.Slice(finalEntries, func(i, j int) bool {
		return tsValue(finalEntries[i]) < tsValue(finalEntries[j])
	})

	return finalEntries, nil
}

func (s *sanitizer) buildActiveEntries(entries []entry) ([]entry, error) {
	activeEntries := make([]entry, 0, len(entries))

	for _, item := range entries {
		files := extractUnique(pathRE, stringValue(item["content"]), 8)
		symbols := extractSymbols(stringValue(item["content"]))

		existingFiles := make([]string, 0, len(files))
		missingFiles := make([]string, 0, len(files))
		for _, rel := range files {
			if full := s.resolveAnchor(rel); full != "" && fileExists(full) {
				existingFiles = append(existingFiles, rel)
			} else {
				missingFiles = append(missingFiles, rel)
			}
		}

		existingSymbols := make([]string, 0, 4)
		missingSymbols := make([]string, 0, 4)
		if len(files) == 0 {
			limit := min(4, len(symbols))
			for _, symbol := range symbols[:limit] {
				exists, err := s.symbolExists(symbol)
				if err != nil {
					return nil, err
				}
				if exists {
					existingSymbols = append(existingSymbols, symbol)
				} else {
					missingSymbols = append(missingSymbols, symbol)
				}
			}
		}

		reasons := []string{}
		status := "active"
		confidence := "medium"

		switch {
		case len(files) > 0 && len(existingFiles) > 0 && len(missingFiles) > 0:
			status = "needs_review"
			confidence = "medium"
			reasons = append(reasons, "partial_missing_file_anchor")
		case len(files) > 0 && len(missingFiles) > 0 && len(existingFiles) == 0:
			status = "stale_candidate"
			confidence = "low"
			reasons = append(reasons, "missing_file_anchor")
		case len(files) > 0:
			status = "active"
			confidence = "high"
			reasons = append(reasons, "file_anchor_match")
		case len(existingSymbols) > 0:
			status = "active"
			confidence = "medium"
			reasons = append(reasons, "symbol_anchor_match")
		case len(missingSymbols) > 0:
			status = "needs_review"
			confidence = "low"
			reasons = append(reasons, "missing_symbol_anchor")
		default:
			reasons = append(reasons, "unanchored_memory")
		}

		item["local_sanitized_ts"] = s.cfg.timestamp
		item["local_confidence"] = confidence
		item["local_status"] = status
		item["local_reasons"] = reasons
		item["local_anchors"] = localAnchors{
			Files:         files,
			Symbols:       symbols,
			ExistingFiles: existingFiles,
			MissingFiles:  missingFiles,
		}

		s.summary[status] = s.summary[status] + 1

		if status == "stale_candidate" {
			s.audit = append(s.audit, auditRecord{
				"ts":         s.cfg.timestamp,
				"action":     "drop_stale_candidate",
				"key":        stringValue(item["key"]),
				"status":     status,
				"confidence": confidence,
				"reasons":    reasons,
				"anchors":    item["local_anchors"],
			})
			continue
		}

		if status == "needs_review" {
			s.audit = append(s.audit, auditRecord{
				"ts":         s.cfg.timestamp,
				"action":     "flag_needs_review",
				"key":        stringValue(item["key"]),
				"status":     status,
				"confidence": confidence,
				"reasons":    reasons,
				"anchors":    item["local_anchors"],
			})
		}

		activeEntries = append(activeEntries, item)
	}

	return activeEntries, nil
}

func (s *sanitizer) resolveAnchor(relPath string) string {
	if s.cfg.projectRoot == "" {
		return ""
	}

	full := filepath.Join(s.cfg.projectRoot, relPath)
	cleaned := filepath.Clean(full)
	if cleaned == s.cfg.projectRoot {
		return ""
	}
	prefix := s.cfg.projectRoot + string(os.PathSeparator)
	if !strings.HasPrefix(cleaned, prefix) {
		return ""
	}
	return cleaned
}

func (s *sanitizer) symbolExists(symbol string) (bool, error) {
	if s.cfg.projectRoot == "" {
		return false, nil
	}
	if cached, ok := s.symbolCache[symbol]; ok {
		return cached, nil
	}

	rgPath, err := exec.LookPath("rg")
	if err != nil {
		s.symbolCache[symbol] = false
		return false, nil
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	cmd := exec.CommandContext(
		ctx,
		rgPath,
		"--files-with-matches",
		"--fixed-strings",
		"--max-count",
		"1",
		"-g",
		"!.git/**",
		"-g",
		"!.lavra/**",
		"-g",
		"!node_modules/**",
		symbol,
		s.cfg.projectRoot,
	)
	if err := cmd.Run(); err != nil {
		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) {
			s.symbolCache[symbol] = false
			return false, nil
		}
		return false, fmt.Errorf("run rg for symbol %q: %w", symbol, err)
	}

	s.symbolCache[symbol] = true
	return true, nil
}

func writeJSONLines[T any](path string, rows []T) error {
	var builder strings.Builder
	writer := bufio.NewWriter(&builder)
	for _, row := range rows {
		payload, err := json.Marshal(row)
		if err != nil {
			return fmt.Errorf("marshal row for %s: %w", path, err)
		}
		if _, err := writer.Write(payload); err != nil {
			return fmt.Errorf("write row for %s: %w", path, err)
		}
		if err := writer.WriteByte('\n'); err != nil {
			return fmt.Errorf("write newline for %s: %w", path, err)
		}
	}
	if err := writer.Flush(); err != nil {
		return fmt.Errorf("flush %s: %w", path, err)
	}
	if err := os.WriteFile(path, []byte(builder.String()), 0o644); err != nil {
		return fmt.Errorf("write %s: %w", path, err)
	}
	return nil
}

func normalizeText(value string) string {
	value = strings.ToLower(value)
	value = commandTrimRE1.ReplaceAllString(value, "")
	value = commandTrimRE2.ReplaceAllString(value, "")
	value = whitespaceRE.ReplaceAllString(value, " ")
	return strings.TrimSpace(value)
}

func canonicalText(value string) string {
	value = normalizeText(value)
	value = nonAlnumRE.ReplaceAllString(value, " ")
	value = whitespaceRE.ReplaceAllString(value, " ")
	return strings.TrimSpace(value)
}

func isNoisy(content string) bool {
	text := normalizeText(content)
	return noiseCommandRE.MatchString(text) ||
		strings.HasPrefix(text, "## ") ||
		strings.HasPrefix(text, "```") ||
		noiseTagRE.MatchString(text)
}

func extractSymbols(content string) []string {
	seen := make(map[string]struct{})
	symbols := make([]string, 0, 6)
	for _, re := range []*regexp.Regexp{backtickSymbolRE, callSymbolRE} {
		for _, match := range re.FindAllStringSubmatch(content, -1) {
			if len(match) < 2 {
				continue
			}
			candidate := match[1]
			if _, ok := seen[candidate]; ok {
				continue
			}
			seen[candidate] = struct{}{}
			symbols = append(symbols, candidate)
			if len(symbols) == 6 {
				return symbols
			}
		}
	}
	return symbols
}

func extractUnique(re *regexp.Regexp, content string, limit int) []string {
	seen := make(map[string]struct{})
	values := make([]string, 0, limit)
	for _, match := range re.FindAllStringSubmatch(content, -1) {
		if len(match) < 2 {
			continue
		}
		candidate := match[1]
		if _, ok := seen[candidate]; ok {
			continue
		}
		seen[candidate] = struct{}{}
		values = append(values, candidate)
		if len(values) == limit {
			return values
		}
	}
	return values
}

func tsValue(item entry) int64 {
	switch value := item["ts"].(type) {
	case float64:
		return int64(value)
	case int64:
		return value
	case int:
		return int64(value)
	case json.Number:
		n, err := value.Int64()
		if err == nil {
			return n
		}
	}
	return 0
}

func stringValue(value any) string {
	if value == nil {
		return ""
	}
	switch typed := value.(type) {
	case string:
		return typed
	default:
		return fmt.Sprint(typed)
	}
}

func fileExists(path string) bool {
	info, err := os.Stat(path)
	if err != nil {
		return false
	}
	return !info.IsDir()
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
