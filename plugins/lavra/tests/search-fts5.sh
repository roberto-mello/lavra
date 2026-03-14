#!/bin/bash
#
# FTS5 search backend - SQLite full-text search with BM25 ranking
#
# Usage: search-fts5.sh "query string" /path/to/knowledge.db [N]
#
# Runs FTS5 MATCH query with BM25 ranking, returns top N keys ordered by relevance.
#

QUERY="$1"
DB_FILE="$2"
TOP_N="${3:-5}"

if [[ -z "$QUERY" ]] || [[ -z "$DB_FILE" ]]; then
  echo "Usage: search-fts5.sh \"query\" /path/to/knowledge.db [N]" >&2
  exit 1
fi

if [[ ! -f "$DB_FILE" ]]; then
  echo "Database not found: $DB_FILE" >&2
  exit 1
fi

# Use Python for proper FTS5 query construction and parameterized execution
python3 - "$QUERY" "$DB_FILE" "$TOP_N" <<'PYEOF'
import sqlite3
import re
import sys

query = sys.argv[1]
db_file = sys.argv[2]
top_n = int(sys.argv[3])

# Extract terms (2+ alphanumeric chars)
terms = re.findall(r'\b[a-zA-Z0-9_.]{2,}\b', query.lower())

if not terms:
    sys.exit(0)

# Build FTS5 query: join with OR
# Quote each term to handle special chars
fts_query = " OR ".join(f'"{t}"' for t in terms)

conn = sqlite3.connect(db_file)
cur = conn.cursor()

# BM25 weights: content=10, tags_text=5, type=2, key=1
try:
    cur.execute("""
        SELECT k.key
        FROM knowledge_fts fts
        JOIN knowledge k ON k.rowid = fts.rowid
        WHERE knowledge_fts MATCH ?
        ORDER BY bm25(knowledge_fts, -10.0, -5.0, -2.0, -1.0)
        LIMIT ?
    """, (fts_query, top_n))

    for row in cur.fetchall():
        print(row[0])

except Exception:
    pass

conn.close()
PYEOF
