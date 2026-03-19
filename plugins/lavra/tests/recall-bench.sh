#!/bin/bash
#
# Memory Recall Benchmark - compare grep vs FTS5 search quality
#
# Usage: recall-bench.sh /path/to/knowledge.jsonl
#
# Runs curated test queries against both grep and FTS5 backends,
# scores results against human-judged relevance labels, and outputs
# a comparison report with precision@5, recall@5, and MRR.
#

set -euo pipefail

KNOWLEDGE_FILE="$1"

if [[ -z "$KNOWLEDGE_FILE" ]]; then
  echo "Usage: recall-bench.sh /path/to/knowledge.jsonl" >&2
  exit 1
fi

if [[ ! -f "$KNOWLEDGE_FILE" ]]; then
  echo "File not found: $KNOWLEDGE_FILE" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_QUERIES="$SCRIPT_DIR/test-queries.jsonl"
GREP_SEARCH="$SCRIPT_DIR/search-grep.sh"
FTS5_SEARCH="$SCRIPT_DIR/search-fts5.sh"
BUILD_INDEX="$SCRIPT_DIR/build-index.sh"

TOP_K=5
DB_FILE=$(mktemp /tmp/recall-bench-XXXXXX.db)
trap 'rm -f "$DB_FILE"' EXIT

# Verify dependencies
for FILE in "$TEST_QUERIES" "$GREP_SEARCH" "$FTS5_SEARCH" "$BUILD_INDEX"; do
  if [[ ! -f "$FILE" ]]; then
    echo "Missing: $FILE" >&2
    exit 1
  fi
done

for CMD in sqlite3 jq; do
  if ! command -v "$CMD" &>/dev/null; then
    echo "Required: $CMD" >&2
    exit 1
  fi
done

# Build FTS5 index
echo "Building FTS5 index..."
bash "$BUILD_INDEX" "$KNOWLEDGE_FILE" "$DB_FILE"
echo ""

# Scoring functions using awk for floating point
calc_precision() {
  local hits="$1"
  local returned="$2"
  if [[ "$returned" -eq 0 ]]; then
    echo "0.000"
  else
    awk "BEGIN { printf \"%.3f\", $hits / $returned }"
  fi
}

calc_recall() {
  local hits="$1"
  local total_relevant="$2"
  if [[ "$total_relevant" -eq 0 ]]; then
    echo "1.000"
  else
    awk "BEGIN { printf \"%.3f\", $hits / $total_relevant }"
  fi
}

calc_rr() {
  # Reciprocal rank: 1/rank of first relevant result, 0 if none
  local rank="$1"
  if [[ "$rank" -eq 0 ]]; then
    echo "0.000"
  else
    awk "BEGIN { printf \"%.3f\", 1.0 / $rank }"
  fi
}

# Run benchmark
TOTAL_QUERIES=0
GREP_P_SUM=0
GREP_R_SUM=0
GREP_RR_SUM=0
FTS5_P_SUM=0
FTS5_R_SUM=0
FTS5_RR_SUM=0

# Header
printf "%-45s | %-17s | %-17s | %-17s\n" "" "Precision@$TOP_K" "Recall@$TOP_K" "MRR"
printf "%-45s | %-8s %-8s | %-8s %-8s | %-8s %-8s\n" "Query" "grep" "fts5" "grep" "fts5" "grep" "fts5"
printf "%s\n" "$(printf '%.0s-' {1..120})"

while IFS= read -r QUERY_LINE; do
  [[ -z "$QUERY_LINE" ]] && continue

  QUERY=$(echo "$QUERY_LINE" | jq -r '.query')
  RELEVANT_KEYS=$(echo "$QUERY_LINE" | jq -r '.relevant_keys[]')
  TOTAL_RELEVANT=$(echo "$QUERY_LINE" | jq -r '.relevant_keys | length')

  # Run grep search
  GREP_RESULTS=$(bash "$GREP_SEARCH" "$QUERY" "$KNOWLEDGE_FILE" "$TOP_K" 2>/dev/null || true)

  # Run FTS5 search
  FTS5_RESULTS=$(bash "$FTS5_SEARCH" "$QUERY" "$DB_FILE" "$TOP_K" 2>/dev/null || true)

  # Score grep results
  GREP_HITS=0
  GREP_FIRST_RANK=0
  GREP_RANK=0
  GREP_RETURNED=0

  while IFS= read -r RESULT_KEY; do
    [[ -z "$RESULT_KEY" ]] && continue
    GREP_RETURNED=$((GREP_RETURNED + 1))
    GREP_RANK=$((GREP_RANK + 1))

    IS_RELEVANT=false
    while IFS= read -r REL_KEY; do
      if [[ "$RESULT_KEY" == "$REL_KEY" ]]; then
        IS_RELEVANT=true
        break
      fi
    done <<< "$RELEVANT_KEYS"

    if $IS_RELEVANT; then
      GREP_HITS=$((GREP_HITS + 1))
      if [[ "$GREP_FIRST_RANK" -eq 0 ]]; then
        GREP_FIRST_RANK=$GREP_RANK
      fi
    fi
  done <<< "$GREP_RESULTS"

  # Score FTS5 results
  FTS5_HITS=0
  FTS5_FIRST_RANK=0
  FTS5_RANK=0
  FTS5_RETURNED=0

  while IFS= read -r RESULT_KEY; do
    [[ -z "$RESULT_KEY" ]] && continue
    FTS5_RETURNED=$((FTS5_RETURNED + 1))
    FTS5_RANK=$((FTS5_RANK + 1))

    IS_RELEVANT=false
    while IFS= read -r REL_KEY; do
      if [[ "$RESULT_KEY" == "$REL_KEY" ]]; then
        IS_RELEVANT=true
        break
      fi
    done <<< "$RELEVANT_KEYS"

    if $IS_RELEVANT; then
      FTS5_HITS=$((FTS5_HITS + 1))
      if [[ "$FTS5_FIRST_RANK" -eq 0 ]]; then
        FTS5_FIRST_RANK=$FTS5_RANK
      fi
    fi
  done <<< "$FTS5_RESULTS"

  # Compute metrics
  G_P=$(calc_precision $GREP_HITS $GREP_RETURNED)
  G_R=$(calc_recall $GREP_HITS $TOTAL_RELEVANT)
  G_RR=$(calc_rr $GREP_FIRST_RANK)

  F_P=$(calc_precision $FTS5_HITS $FTS5_RETURNED)
  F_R=$(calc_recall $FTS5_HITS $TOTAL_RELEVANT)
  F_RR=$(calc_rr $FTS5_FIRST_RANK)

  # Print row
  QUERY_DISPLAY="$QUERY"
  if [[ ${#QUERY_DISPLAY} -gt 43 ]]; then
    QUERY_DISPLAY="${QUERY_DISPLAY:0:40}..."
  fi
  printf "%-45s | %-8s %-8s | %-8s %-8s | %-8s %-8s\n" "$QUERY_DISPLAY" "$G_P" "$F_P" "$G_R" "$F_R" "$G_RR" "$F_RR"

  # Accumulate for averages
  GREP_P_SUM=$(awk "BEGIN { print $GREP_P_SUM + $G_P }")
  GREP_R_SUM=$(awk "BEGIN { print $GREP_R_SUM + $G_R }")
  GREP_RR_SUM=$(awk "BEGIN { print $GREP_RR_SUM + $G_RR }")
  FTS5_P_SUM=$(awk "BEGIN { print $FTS5_P_SUM + $F_P }")
  FTS5_R_SUM=$(awk "BEGIN { print $FTS5_R_SUM + $F_R }")
  FTS5_RR_SUM=$(awk "BEGIN { print $FTS5_RR_SUM + $F_RR }")
  TOTAL_QUERIES=$((TOTAL_QUERIES + 1))

done < "$TEST_QUERIES"

# Summary
printf "%s\n" "$(printf '%.0s-' {1..120})"

if [[ $TOTAL_QUERIES -gt 0 ]]; then
  AVG_GP=$(awk "BEGIN { printf \"%.3f\", $GREP_P_SUM / $TOTAL_QUERIES }")
  AVG_GR=$(awk "BEGIN { printf \"%.3f\", $GREP_R_SUM / $TOTAL_QUERIES }")
  AVG_GRR=$(awk "BEGIN { printf \"%.3f\", $GREP_RR_SUM / $TOTAL_QUERIES }")
  AVG_FP=$(awk "BEGIN { printf \"%.3f\", $FTS5_P_SUM / $TOTAL_QUERIES }")
  AVG_FR=$(awk "BEGIN { printf \"%.3f\", $FTS5_R_SUM / $TOTAL_QUERIES }")
  AVG_FRR=$(awk "BEGIN { printf \"%.3f\", $FTS5_RR_SUM / $TOTAL_QUERIES }")

  printf "%-45s | %-8s %-8s | %-8s %-8s | %-8s %-8s\n" "AVERAGE ($TOTAL_QUERIES queries)" "$AVG_GP" "$AVG_FP" "$AVG_GR" "$AVG_FR" "$AVG_GRR" "$AVG_FRR"

  echo ""
  echo "Legend:"
  echo "  Precision@$TOP_K = relevant results / returned results (higher = less noise)"
  echo "  Recall@$TOP_K    = relevant results / total relevant (higher = more complete)"
  echo "  MRR           = 1/rank of first relevant result (higher = faster to find)"

  # Delta summary
  DELTA_P=$(awk "BEGIN { printf \"%+.3f\", $AVG_FP - $AVG_GP }")
  DELTA_R=$(awk "BEGIN { printf \"%+.3f\", $AVG_FR - $AVG_GR }")
  DELTA_RR=$(awk "BEGIN { printf \"%+.3f\", $AVG_FRR - $AVG_GRR }")

  echo ""
  echo "FTS5 vs grep delta:"
  echo "  Precision: $DELTA_P"
  echo "  Recall:    $DELTA_R"
  echo "  MRR:       $DELTA_RR"
fi
