#!/bin/bash
#
# Grep search backend - mirrors the current recall.sh/auto-recall.sh logic
#
# Usage: search-grep.sh "query string" /path/to/knowledge.jsonl [N]
#
# Splits query into terms, greps each, deduplicates by key, returns top N keys.
#

QUERY="$1"
KNOWLEDGE_FILE="$2"
TOP_N="${3:-5}"

if [[ -z "$QUERY" ]] || [[ -z "$KNOWLEDGE_FILE" ]]; then
  echo "Usage: search-grep.sh \"query\" /path/to/knowledge.jsonl [N]" >&2
  exit 1
fi

if [[ ! -f "$KNOWLEDGE_FILE" ]]; then
  echo "File not found: $KNOWLEDGE_FILE" >&2
  exit 1
fi

# Split query into terms (matching auto-recall.sh approach)
TERMS=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]' | grep -oE '\b[a-zA-Z0-9_.]{2,}\b')

SEEN_KEYS=""
RESULT_KEYS=""
COUNT=0

for TERM in $TERMS; do
  [[ $COUNT -ge $TOP_N ]] && break

  # grep -i for case-insensitive matching (mirrors recall.sh line 96)
  MATCHES=$(grep -i "$TERM" "$KNOWLEDGE_FILE" 2>/dev/null)

  while IFS= read -r LINE; do
    [[ -z "$LINE" ]] && continue
    [[ $COUNT -ge $TOP_N ]] && break

    KEY=$(echo "$LINE" | jq -r '.key // empty' 2>/dev/null)
    [[ -z "$KEY" ]] && continue

    # Deduplicate
    if [[ "$SEEN_KEYS" != *"|$KEY|"* ]]; then
      SEEN_KEYS="${SEEN_KEYS}|${KEY}|"
      RESULT_KEYS="${RESULT_KEYS}${KEY}"$'\n'
      COUNT=$((COUNT + 1))
    fi
  done <<< "$MATCHES"
done

# Output keys, one per line, trimming trailing newline
echo "$RESULT_KEYS" | sed '/^$/d'
