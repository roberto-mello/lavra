package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestRunDedupesAndFiltersNoise(t *testing.T) {
	t.Parallel()

	tempDir := t.TempDir()
	cfg := config{
		knowledgeFile: writeLines(t, tempDir, "knowledge.jsonl", []string{
			`{"key":"alpha","type":"learned","content":"OAuth redirect URI must match exactly","ts":10}`,
			`{"key":"ALPHA","type":"learned","content":"OAuth redirect URI must match exactly","ts":9}`,
			`{"key":"beta","type":"learned","content":"git status","ts":8}`,
			`not-json`,
			`{"key":"gamma","type":"learned","content":"OAuth redirect URI must match exactly!!!","ts":7}`,
		}),
		activeFile: filepath.Join(tempDir, "active.jsonl"),
		auditFile:  filepath.Join(tempDir, "audit.jsonl"),
		timestamp:  111,
	}

	if err := run(cfg); err != nil {
		t.Fatalf("run failed: %v", err)
	}

	active := readEntries(t, cfg.activeFile)
	if len(active) != 1 {
		t.Fatalf("expected 1 active entry, got %d", len(active))
	}
	if got := stringValue(active[0]["key"]); got != "alpha" {
		t.Fatalf("expected newest key alpha to survive, got %q", got)
	}

	audit := readEntries(t, cfg.auditFile)
	assertAuditAction(t, audit, "skip_invalid_json")
	assertAuditAction(t, audit, "filter_noise")
	assertAuditAction(t, audit, "dedupe_key")
	assertAuditAction(t, audit, "dedupe_content")
}

func TestRunMarksMissingFileAnchorAsStaleCandidate(t *testing.T) {
	t.Parallel()

	tempDir := t.TempDir()
	projectRoot := filepath.Join(tempDir, "project")
	if err := os.MkdirAll(projectRoot, 0o755); err != nil {
		t.Fatalf("mkdir project root: %v", err)
	}

	cfg := config{
		knowledgeFile: writeLines(t, tempDir, "knowledge.jsonl", []string{
			`{"key":"stale","type":"learned","content":"Check app/missing.rb before editing","ts":10}`,
		}),
		activeFile:  filepath.Join(tempDir, "active.jsonl"),
		auditFile:   filepath.Join(tempDir, "audit.jsonl"),
		projectRoot: projectRoot,
		timestamp:   222,
	}

	if err := run(cfg); err != nil {
		t.Fatalf("run failed: %v", err)
	}

	active := readEntries(t, cfg.activeFile)
	if len(active) != 0 {
		t.Fatalf("expected stale candidate to be dropped, got %d active entries", len(active))
	}

	audit := readEntries(t, cfg.auditFile)
	assertAuditAction(t, audit, "drop_stale_candidate")
}

func TestRunUsesSymbolAnchorsForNeedsReview(t *testing.T) {
	tempDir := t.TempDir()
	projectRoot := filepath.Join(tempDir, "project")
	if err := os.MkdirAll(projectRoot, 0o755); err != nil {
		t.Fatalf("mkdir project root: %v", err)
	}
	fakeRGDir := filepath.Join(tempDir, "bin")
	if err := os.MkdirAll(fakeRGDir, 0o755); err != nil {
		t.Fatalf("mkdir bin dir: %v", err)
	}
	rgPath := filepath.Join(fakeRGDir, "rg")
	rgScript := "#!/bin/sh\nfor arg in \"$@\"; do\n  if [ \"$arg\" = \"existingfunc\" ]; then\n    exit 0\n  fi\ndone\nexit 1\n"
	if err := os.WriteFile(rgPath, []byte(rgScript), 0o755); err != nil {
		t.Fatalf("write fake rg: %v", err)
	}
	t.Setenv("PATH", fakeRGDir+string(os.PathListSeparator)+os.Getenv("PATH"))

	cfg := config{
		knowledgeFile: writeLines(t, tempDir, "knowledge.jsonl", []string{
			`{"key":"existing","type":"learned","content":"Call existingfunc() after boot","ts":10}`,
			`{"key":"missing","type":"learned","content":"Call missingfunc() after boot","ts":11}`,
		}),
		activeFile:  filepath.Join(tempDir, "active.jsonl"),
		auditFile:   filepath.Join(tempDir, "audit.jsonl"),
		projectRoot: projectRoot,
		timestamp:   333,
	}

	if err := run(cfg); err != nil {
		t.Fatalf("run failed: %v", err)
	}

	active := readEntries(t, cfg.activeFile)
	if len(active) != 2 {
		t.Fatalf("expected 2 active entries, got %d", len(active))
	}

	statusByKey := map[string]string{}
	for _, item := range active {
		statusByKey[stringValue(item["key"])] = stringValue(item["local_status"])
	}
	if statusByKey["existing"] != "active" {
		t.Fatalf("expected existing symbol to be active, got %q", statusByKey["existing"])
	}
	if statusByKey["missing"] != "needs_review" {
		t.Fatalf("expected missing symbol to be needs_review, got %q", statusByKey["missing"])
	}

	audit := readEntries(t, cfg.auditFile)
	assertAuditAction(t, audit, "flag_needs_review")
}

func writeLines(t *testing.T, dir, name string, lines []string) string {
	t.Helper()

	path := filepath.Join(dir, name)
	content := ""
	for _, line := range lines {
		content += line + "\n"
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("write %s: %v", path, err)
	}
	return path
}

func readEntries(t *testing.T, path string) []map[string]any {
	t.Helper()

	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	if len(data) == 0 {
		return nil
	}

	lines := splitNonEmptyLines(string(data))
	entries := make([]map[string]any, 0, len(lines))
	for _, line := range lines {
		var item map[string]any
		if err := json.Unmarshal([]byte(line), &item); err != nil {
			t.Fatalf("unmarshal %s line %q: %v", path, line, err)
		}
		entries = append(entries, item)
	}
	return entries
}

func splitNonEmptyLines(value string) []string {
	lines := []string{}
	current := ""
	for _, ch := range value {
		if ch == '\n' {
			if current != "" {
				lines = append(lines, current)
			}
			current = ""
			continue
		}
		current += string(ch)
	}
	if current != "" {
		lines = append(lines, current)
	}
	return lines
}

func assertAuditAction(t *testing.T, entries []map[string]any, want string) {
	t.Helper()

	for _, item := range entries {
		if stringValue(item["action"]) == want {
			return
		}
	}
	t.Fatalf("expected audit action %q", want)
}
