#!/bin/bash
#
# Build SQLite FTS5 index from knowledge.jsonl
#
# Usage: build-index.sh /path/to/knowledge.jsonl /path/to/output.db
#
# Creates a SQLite database with:
# - knowledge table with all fields
# - knowledge_fts FTS5 virtual table for full-text search
#

KNOWLEDGE_FILE="$1"
DB_FILE="$2"

if [[ -z "$KNOWLEDGE_FILE" ]] || [[ -z "$DB_FILE" ]]; then
  echo "Usage: build-index.sh /path/to/knowledge.jsonl /path/to/output.db" >&2
  exit 1
fi

if [[ ! -f "$KNOWLEDGE_FILE" ]]; then
  echo "File not found: $KNOWLEDGE_FILE" >&2
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo "Required: python3" >&2
  exit 1
fi

# Remove existing db to start fresh
rm -f "$DB_FILE"

# Use Python for proper parameterized SQL (no escaping issues)
python3 - "$KNOWLEDGE_FILE" "$DB_FILE" <<'PYEOF'
import json
import sqlite3
import sys

knowledge_file = sys.argv[1]
db_file = sys.argv[2]

conn = sqlite3.connect(db_file)
cur = conn.cursor()

cur.executescript("""
CREATE TABLE knowledge(
  key TEXT PRIMARY KEY,
  type TEXT,
  content TEXT,
  source TEXT,
  tags_text TEXT,
  ts INTEGER,
  bead TEXT
);

CREATE VIRTUAL TABLE knowledge_fts USING fts5(
  content, tags_text, type, key,
  content=knowledge,
  content_rowid=rowid,
  tokenize='porter unicode61'
);

CREATE TRIGGER knowledge_ai AFTER INSERT ON knowledge BEGIN
  INSERT INTO knowledge_fts(rowid, content, tags_text, type, key)
  VALUES (new.rowid, new.content, new.tags_text, new.type, new.key);
END;
""")

inserted = 0
skipped = 0

with open(knowledge_file, encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue

        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            skipped += 1
            continue

        key = entry.get("key", "")
        if not key:
            skipped += 1
            continue

        tags = entry.get("tags", [])
        tags_text = " ".join(tags) if isinstance(tags, list) else str(tags)

        try:
            cur.execute(
                "INSERT OR IGNORE INTO knowledge(key, type, content, source, tags_text, ts, bead) VALUES(?, ?, ?, ?, ?, ?, ?)",
                (
                    key,
                    entry.get("type", ""),
                    entry.get("content", ""),
                    entry.get("source", ""),
                    tags_text,
                    entry.get("ts", 0),
                    entry.get("bead", ""),
                ),
            )
            inserted += 1
        except Exception as e:
            print(f"  Warning: skipped {key}: {e}", file=sys.stderr)
            skipped += 1

conn.commit()
conn.close()

print(f"Built FTS5 index: {db_file}")
print(f"  Entries indexed: {inserted}")
print(f"  Entries skipped: {skipped}")
PYEOF
