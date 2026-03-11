#!/usr/bin/env node

"use strict";

const { execFileSync } = require("child_process");

const BEAD_ID_RE = /^[a-zA-Z0-9][a-zA-Z0-9._-]*$/;

function validateBeadId(id) {
  if (!BEAD_ID_RE.test(id)) {
    console.error(`  Error: invalid bead ID: ${JSON.stringify(id)}`);
    process.exit(1);
  }
}
const fs = require("fs");
const path = require("path");

// ---------------------------------------------------------------------------
// CLI argument parsing
// ---------------------------------------------------------------------------

const args = process.argv.slice(2);

function usage(exitCode = 1) {
  console.error("");
  console.error("  bd-plan-export - Export a plan tree as markdown");
  console.error("");
  console.error("  Usage:");
  console.error("    bd-plan-export <bead-id>");
  console.error("    bd-plan-export <bead-id> --output <path>");
  console.error("");
  console.error("  Options:");
  console.error("    --output, -o <path>   Write to file instead of stdout");
  console.error("    --help, -h            Show this help");
  console.error("");
  process.exit(exitCode);
}

if (args.includes("--help") || args.includes("-h")) {
  usage(0);
}
if (args.length === 0) {
  usage();
}

// Parse arguments
let beadId = null;
let outputPath = null;

for (let i = 0; i < args.length; i++) {
  if (args[i] === "--output" || args[i] === "-o") {
    i++;
    if (i >= args.length) {
      console.error("  Error: --output requires a path argument");
      process.exit(1);
    }
    outputPath = args[i];
  } else if (!args[i].startsWith("-")) {
    if (!beadId) {
      beadId = args[i];
    } else {
      console.error(`  Error: unexpected argument: ${args[i]}`);
      process.exit(1);
    }
  } else {
    console.error(`  Error: unknown flag: ${args[i]}`);
    process.exit(1);
  }
}

if (!beadId) {
  console.error("  Error: bead ID is required");
  process.exit(1);
}

// ---------------------------------------------------------------------------
// Data fetching
// ---------------------------------------------------------------------------

function bdExecFile(args) {
  try {
    return execFileSync("bd", args, { encoding: "utf8", stdio: ["pipe", "pipe", "pipe"], timeout: 30000 });
  } catch (err) {
    const stderr = err.stderr ? err.stderr.trim() : err.message;
    console.error(`  Error running: bd ${args.join(" ")}`);
    console.error(`  ${stderr}`);
    process.exit(1);
  }
}

function fetchBead(id) {
  validateBeadId(id);
  const raw = bdExecFile(["show", id, "--json"]);
  try {
    return JSON.parse(raw);
  } catch {
    console.error(`  Error: failed to parse JSON from 'bd show ${id} --json'`);
    process.exit(1);
  }
}

function fetchChildren(parentId) {
  validateBeadId(parentId);
  const raw = bdExecFile(["list", "--parent", parentId, "--json"]);
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function fetchComments(id) {
  validateBeadId(id);
  const raw = bdExecFile(["comments", "list", id]);
  return raw.trim();
}

// ---------------------------------------------------------------------------
// Comment parsing
// ---------------------------------------------------------------------------

const KNOWLEDGE_PREFIXES = ["LEARNED", "DECISION", "FACT", "PATTERN", "INVESTIGATION"];

function parseKnowledgeComments(commentText) {
  const decisions = [];
  const knowledge = [];

  if (!commentText) return { decisions, knowledge };

  const lines = commentText.split("\n");
  for (const line of lines) {
    const trimmed = line.trim();
    for (const prefix of KNOWLEDGE_PREFIXES) {
      const pattern = `${prefix}:`;
      const idx = trimmed.indexOf(pattern);
      if (idx !== -1) {
        const entry = trimmed.substring(idx).trim();
        if (prefix === "DECISION") {
          decisions.push(entry);
        } else {
          knowledge.push(entry);
        }
        break;
      }
    }
  }

  return { decisions, knowledge };
}

// ---------------------------------------------------------------------------
// Date formatting
// ---------------------------------------------------------------------------

function formatDate(dateStr) {
  if (!dateStr) return "unknown";
  try {
    const d = new Date(dateStr);
    return d.toISOString().split("T")[0];
  } catch {
    return dateStr;
  }
}

// ---------------------------------------------------------------------------
// Markdown generation
// ---------------------------------------------------------------------------

function buildMarkdown(epic, children, epicComments, childComments) {
  const lines = [];

  // Epic header
  const title = epic.title || epic.name || epic.id || beadId;
  lines.push(`# Plan: ${title}`);
  lines.push("");

  const status = epic.status || "unknown";
  const priority = epic.priority != null ? `P${epic.priority}` : "unset";
  const created = formatDate(epic.created_at || epic.created || epic.date);
  lines.push(`**Status:** ${status} | **Priority:** ${priority} | **Created:** ${created}`);
  lines.push("");

  // Epic description
  const description = epic.description || epic.body || "";
  if (description) {
    lines.push("## Description");
    lines.push("");
    lines.push(description.trim());
    lines.push("");
  }

  // Epic decisions
  const epicParsed = parseKnowledgeComments(epicComments);
  if (epicParsed.decisions.length > 0) {
    lines.push("## Decisions");
    lines.push("");
    for (const d of epicParsed.decisions) {
      lines.push(`- ${d}`);
    }
    lines.push("");
  }

  // Epic knowledge (non-decision)
  if (epicParsed.knowledge.length > 0) {
    lines.push("## Knowledge");
    lines.push("");
    for (const k of epicParsed.knowledge) {
      lines.push(`- ${k}`);
    }
    lines.push("");
  }

  // Children (phases)
  if (children.length > 0) {
    for (let i = 0; i < children.length; i++) {
      const child = children[i];
      const childTitle = child.title || child.name || child.id;
      const childId = child.id || "";
      const childStatus = child.status || "unknown";
      const childDesc = child.description || child.body || "";

      lines.push("---");
      lines.push("");
      lines.push(`## Phase ${i + 1}: ${childTitle}`);
      lines.push("");
      lines.push(`**Status:** ${childStatus} | **Bead:** ${childId}`);
      lines.push("");

      if (childDesc) {
        lines.push(childDesc.trim());
        lines.push("");
      }

      const childParsed = parseKnowledgeComments(childComments[i]);

      if (childParsed.decisions.length > 0) {
        lines.push("### Decisions");
        lines.push("");
        for (const d of childParsed.decisions) {
          lines.push(`- ${d}`);
        }
        lines.push("");
      }

      if (childParsed.knowledge.length > 0) {
        lines.push("### Knowledge");
        lines.push("");
        for (const k of childParsed.knowledge) {
          lines.push(`- ${k}`);
        }
        lines.push("");
      }
    }
  }

  return lines.join("\n");
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

function main() {
  // Fetch epic
  const epic = fetchBead(beadId);

  // Fetch children
  const children = fetchChildren(beadId);

  // Fetch comments for epic
  const epicComments = fetchComments(beadId);

  // Fetch comments for each child
  const childComments = [];
  for (const child of children) {
    const cid = child.id;
    if (cid) {
      childComments.push(fetchComments(cid));
    } else {
      childComments.push("");
    }
  }

  // Build markdown
  const markdown = buildMarkdown(epic, children, epicComments, childComments);

  // Output
  if (outputPath) {
    const resolved = path.resolve(outputPath);
    const dir = path.dirname(resolved);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(resolved, markdown, "utf8");
    console.error(`  Written to ${resolved}`);
  } else {
    process.stdout.write(markdown);
  }
}

main();
