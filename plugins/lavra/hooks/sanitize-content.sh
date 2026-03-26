#!/usr/bin/env bash
#
# sanitize-content.sh
#
# Shared sanitization library for lavra hooks and scripts.
# Source this file, then call sanitize_untrusted_content via stdin.
#
# Usage:
#   source /path/to/sanitize-content.sh
#   clean=$(echo "$raw" | sanitize_untrusted_content)
#
# What it strips:
#   - Role-injection prefixes: SYSTEM:, ASSISTANT:, USER:, HUMAN:, [INST], [/INST]
#   - Sentence boundary tags: <s>, </s>
#   - Carriage returns and null bytes
#   - Unicode bidirectional override characters (U+202A-U+202E, U+2066-U+2069)
#     that can reorder displayed text to hide malicious content
#
# Line limit: callers are responsible for truncation (head -N) if needed,
# since the appropriate limit varies by context.

sanitize_untrusted_content() {
  sed -E 's/SYSTEM://gi; s/ASSISTANT://gi; s/USER://gi; s/HUMAN://gi; s/\[INST\]//gi; s/\[\/INST\]//gi' |
  sed -E 's/<s>//g; s/<\/s>//g' |
  tr -d '\r\000' |
  sed -E 's/[\x{202A}-\x{202E}\x{2066}-\x{2069}]//g'
}
