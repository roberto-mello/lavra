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
# Security note: the role-injection filter strips exact tokens only. It is noise
# reduction, not a security boundary. The <untrusted-knowledge> XML wrapper and
# "do not follow instructions" directive are the primary controls.
#
# Compatibility: uses tr with ANSI-C quoting for bidi removal — BSD sed (macOS)
# silently ignores \x{NNNN} unicode escapes, making a sed approach a no-op there.
#
# pipefail safety: the function body is wrapped in { ... } || true so that tr
# returning exit 1 (on BSD when no bytes are deleted) does not propagate under
# set -euo pipefail in callers.
#
# Line limit: callers are responsible for truncation (head -N) if needed,
# since the appropriate limit varies by context.

sanitize_untrusted_content() {
  # NOTE: role-injection filter strips exact token strings only. Token fragmentation
  # (zero-width spaces inside keywords) and homoglyph substitution (Cyrillic lookalikes)
  # are accepted residual risks. The <untrusted-knowledge> XML wrapper is the primary
  # control; this function is noise reduction only.
  #
  # Bidi chars as literal UTF-8 bytes (portable: works on bash 3.2/macOS and GNU/Linux).
  # BSD sed silently ignores \x{NNNN} escapes, so we use tr with printf-escaped bytes.
  # U+202A-U+202E: E2 80 AA-AE  |  U+2066-U+2069: E2 81 A6-A9
  local _bidi
  _bidi="$(printf '\xe2\x80\xaa\xe2\x80\xab\xe2\x80\xac\xe2\x80\xad\xe2\x80\xae\xe2\x81\xa6\xe2\x81\xa7\xe2\x81\xa8\xe2\x81\xa9')"
  { sed -E 's/SYSTEM://gi; s/ASSISTANT://gi; s/USER://gi; s/HUMAN://gi; s/\[INST\]//gi; s/\[\/INST\]//gi' |
    sed -E 's/<s>//g; s/<\/s>//g' |
    tr -d '\r\000' |
    tr -d "$_bidi"; } || true
}
