#!/usr/bin/env node

"use strict";

const { execFileSync } = require("child_process");

const BEAD_ID_RE = /^[a-zA-Z0-9][a-zA-Z0-9._-]*$/;

function validateBeadId(id) {
  if (!BEAD_ID_RE.test(id)) {
    process.stderr.write(`Error: invalid bead ID: ${JSON.stringify(id)}\n`);
    process.exit(1);
  }
}
const readline = require("readline");

// ---------------------------------------------------------------------------
// ANSI Colors
// ---------------------------------------------------------------------------

const C = {
  reset: "\x1b[0m",
  bold: "\x1b[1m",
  dim: "\x1b[2m",
  underline: "\x1b[4m",
  // Foreground
  black: "\x1b[30m",
  red: "\x1b[31m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  blue: "\x1b[34m",
  magenta: "\x1b[35m",
  cyan: "\x1b[36m",
  white: "\x1b[37m",
  gray: "\x1b[90m",
  // Background
  bgBlack: "\x1b[40m",
  bgBlue: "\x1b[44m",
  bgCyan: "\x1b[46m",
  bgWhite: "\x1b[47m",
};

// ---------------------------------------------------------------------------
// Status indicators
// ---------------------------------------------------------------------------

const STATUS_ICON = {
  closed: `${C.green}[x]${C.reset}`,
  in_progress: `${C.yellow}[>]${C.reset}`,
  open: `${C.gray}[ ]${C.reset}`,
  blocked: `${C.red}[!]${C.reset}`,
};

function statusIcon(status) {
  return STATUS_ICON[status] || STATUS_ICON.open;
}

// ---------------------------------------------------------------------------
// Data fetching via bd CLI
// ---------------------------------------------------------------------------

function bdExecFile(args) {
  try {
    return execFileSync("bd", args, {
      encoding: "utf8",
      timeout: 30000,
      stdio: ["pipe", "pipe", "pipe"],
    }).trim();
  } catch (err) {
    return "";
  }
}

function bdShowJson(beadId) {
  validateBeadId(beadId);
  const raw = bdExecFile(["show", beadId, "--json"]);
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function bdListChildren(parentId) {
  validateBeadId(parentId);
  const raw = bdExecFile(["list", "--parent", parentId, "--json"]);
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function bdCommentsList(beadId) {
  validateBeadId(beadId);
  const raw = bdExecFile(["comments", "list", beadId]);
  if (!raw) return [];
  return raw.split("\n").filter((line) => line.trim());
}

function extractDecisions(comments) {
  return comments.filter((line) => {
    const upper = line.toUpperCase();
    return upper.includes("DECISION:");
  });
}

// ---------------------------------------------------------------------------
// Tree model
// ---------------------------------------------------------------------------

/**
 * Each tree node:
 * {
 *   id: string,
 *   title: string,
 *   status: string,
 *   type: "epic" | "phase" | "task",
 *   depth: number,
 *   expanded: boolean,
 *   children: TreeNode[],
 *   data: object,       // raw bd show data
 *   comments: string[],
 *   decisions: string[],
 * }
 */

function buildTree(rootId) {
  const rootData = bdShowJson(rootId);
  if (!rootData) {
    die(`Could not find bead: ${rootId}`);
  }

  const rootComments = bdCommentsList(rootId);
  const root = {
    id: rootId,
    title: rootData.title || rootId,
    status: rootData.status || "open",
    type: "epic",
    depth: 0,
    expanded: true,
    children: [],
    data: rootData,
    comments: rootComments,
    decisions: extractDecisions(rootComments),
  };

  // Load phases (direct children)
  const phases = bdListChildren(rootId);
  for (const phase of phases) {
    const phaseId = phase.id || phase.bead_id;
    if (!phaseId) continue;

    const phaseData = bdShowJson(phaseId) || phase;
    const phaseComments = bdCommentsList(phaseId);
    const phaseChildren = bdListChildren(phaseId);

    const phaseNode = {
      id: phaseId,
      title: phaseData.title || phase.title || phaseId,
      status: phaseData.status || phase.status || "open",
      type: "phase",
      depth: 1,
      expanded: false,
      children: [],
      data: phaseData,
      comments: phaseComments,
      decisions: extractDecisions(phaseComments),
    };

    // Load tasks (children of phase)
    for (const task of phaseChildren) {
      const taskId = task.id || task.bead_id;
      if (!taskId) continue;

      const taskData = bdShowJson(taskId) || task;
      const taskComments = bdCommentsList(taskId);

      phaseNode.children.push({
        id: taskId,
        title: taskData.title || task.title || taskId,
        status: taskData.status || task.status || "open",
        type: "task",
        depth: 2,
        expanded: false,
        children: [],
        data: taskData,
        comments: taskComments,
        decisions: extractDecisions(taskComments),
      });
    }

    root.children.push(phaseNode);
  }

  return root;
}

// ---------------------------------------------------------------------------
// Flatten tree for display (respects expanded state)
// ---------------------------------------------------------------------------

function flattenTree(node) {
  const result = [node];
  if (node.expanded && node.children.length > 0) {
    for (const child of node.children) {
      result.push(...flattenTree(child));
    }
  }
  return result;
}

// ---------------------------------------------------------------------------
// Terminal helpers
// ---------------------------------------------------------------------------

function getTermSize() {
  return {
    cols: process.stdout.columns || 80,
    rows: process.stdout.rows || 24,
  };
}

function moveCursor(row, col) {
  process.stdout.write(`\x1b[${row};${col}H`);
}

function clearScreen() {
  process.stdout.write("\x1b[2J\x1b[H");
}

function hideCursor() {
  process.stdout.write("\x1b[?25l");
}

function showCursor() {
  process.stdout.write("\x1b[?25h");
}

// Strip ANSI codes for length calculation
function stripAnsi(str) {
  return str.replace(/\x1b\[[0-9;]*m/g, "");
}

function truncate(str, maxLen) {
  const plain = stripAnsi(str);
  if (plain.length <= maxLen) return str;
  // Truncate the plain text, but we need to handle ANSI codes
  let visible = 0;
  let i = 0;
  while (i < str.length && visible < maxLen - 1) {
    if (str[i] === "\x1b") {
      const end = str.indexOf("m", i);
      if (end !== -1) {
        i = end + 1;
        continue;
      }
    }
    visible++;
    i++;
  }
  return str.slice(0, i) + C.reset + "\u2026";
}

function padRight(str, width) {
  const plain = stripAnsi(str);
  const pad = Math.max(0, width - plain.length);
  return str + " ".repeat(pad);
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

function renderTreeLine(node, isSelected, width) {
  const indent = "  ".repeat(node.depth);
  const icon = statusIcon(node.status);
  const expandIndicator =
    node.children.length > 0 ? (node.expanded ? "\u25BC " : "\u25B6 ") : "  ";

  const typeLabel =
    node.type === "epic"
      ? `${C.bold}${C.magenta}Epic:${C.reset} `
      : node.type === "phase"
        ? `${C.cyan}Phase:${C.reset} `
        : "";

  const childCount =
    node.children.length > 0
      ? ` ${C.dim}(${node.children.length})${C.reset}`
      : "";

  let line = `${indent}${icon} ${expandIndicator}${typeLabel}${C.bold}${node.id}${C.reset} ${C.dim}\u2014${C.reset} ${node.title}${childCount}`;

  if (isSelected) {
    line = `${C.bgBlue}${C.white}${padRight(line, width)}${C.reset}`;
  } else {
    line = padRight(line, width);
  }

  return truncate(line, width);
}

function renderDetailPanel(node, width, height) {
  const lines = [];
  const hr = C.dim + "\u2500".repeat(width - 2) + C.reset;

  // Header
  lines.push(`${C.bold}${C.cyan}${node.id}${C.reset}`);
  lines.push(`${C.bold}${node.title}${C.reset}`);
  lines.push("");

  // Status and type
  lines.push(`${C.dim}Type:${C.reset}   ${node.type}`);
  lines.push(`${C.dim}Status:${C.reset} ${statusIcon(node.status)} ${node.status}`);

  // Additional fields from data
  const data = node.data || {};
  if (data.priority) {
    lines.push(`${C.dim}Priority:${C.reset} ${data.priority}`);
  }
  if (data.assignee) {
    lines.push(`${C.dim}Assignee:${C.reset} ${data.assignee}`);
  }
  if (data.labels && data.labels.length > 0) {
    lines.push(
      `${C.dim}Labels:${C.reset}   ${data.labels.join(", ")}`
    );
  }
  if (data.parent) {
    lines.push(`${C.dim}Parent:${C.reset}  ${data.parent}`);
  }

  lines.push("");
  lines.push(hr);

  // Description
  if (data.description || data.body) {
    lines.push(`${C.bold}Description${C.reset}`);
    lines.push("");
    const desc = data.description || data.body || "";
    const descLines = desc.split("\n");
    for (const dl of descLines) {
      // Word-wrap long lines
      const wrapped = wordWrap(dl, width - 2);
      lines.push(...wrapped);
    }
    lines.push("");
    lines.push(hr);
  }

  // Decisions
  if (node.decisions.length > 0) {
    lines.push(`${C.bold}${C.yellow}Locked Decisions${C.reset}`);
    lines.push("");
    for (const dec of node.decisions) {
      const wrapped = wordWrap(dec, width - 4);
      for (const w of wrapped) {
        lines.push(`  ${C.yellow}\u2022${C.reset} ${w}`);
      }
    }
    lines.push("");
    lines.push(hr);
  }

  // Comments summary
  if (node.comments.length > 0) {
    const nonDecision = node.comments.filter(
      (c) => !c.toUpperCase().includes("DECISION:")
    );
    lines.push(
      `${C.bold}Comments${C.reset} ${C.dim}(${node.comments.length} total, ${node.decisions.length} decisions)${C.reset}`
    );
    lines.push("");
    const showCount = Math.min(nonDecision.length, 10);
    for (let i = 0; i < showCount; i++) {
      const wrapped = wordWrap(nonDecision[i], width - 4);
      for (const w of wrapped) {
        lines.push(`  ${C.dim}\u2502${C.reset} ${w}`);
      }
    }
    if (nonDecision.length > showCount) {
      lines.push(
        `  ${C.dim}... and ${nonDecision.length - showCount} more${C.reset}`
      );
    }
    lines.push("");
    lines.push(hr);
  }

  // Children summary
  if (node.children.length > 0) {
    const closed = node.children.filter((c) => c.status === "closed").length;
    const inProg = node.children.filter(
      (c) => c.status === "in_progress"
    ).length;
    const open = node.children.filter((c) => c.status === "open").length;
    const blocked = node.children.filter((c) => c.status === "blocked").length;

    lines.push(
      `${C.bold}Children${C.reset} ${C.dim}(${node.children.length} total)${C.reset}`
    );
    lines.push("");
    if (closed > 0) lines.push(`  ${C.green}[x]${C.reset} Closed: ${closed}`);
    if (inProg > 0)
      lines.push(`  ${C.yellow}[>]${C.reset} In Progress: ${inProg}`);
    if (open > 0) lines.push(`  ${C.gray}[ ]${C.reset} Open: ${open}`);
    if (blocked > 0) lines.push(`  ${C.red}[!]${C.reset} Blocked: ${blocked}`);
  }

  // Pad/trim to height
  while (lines.length < height) {
    lines.push("");
  }

  return lines.slice(0, height);
}

function wordWrap(text, maxWidth) {
  if (!text) return [""];
  const plain = stripAnsi(text);
  if (plain.length <= maxWidth) return [text];

  const words = text.split(/\s+/);
  const result = [];
  let current = "";

  for (const word of words) {
    const plainCurrent = stripAnsi(current);
    const plainWord = stripAnsi(word);

    if (plainCurrent.length + plainWord.length + 1 > maxWidth) {
      if (current) result.push(current);
      current = word;
    } else {
      current = current ? current + " " + word : word;
    }
  }
  if (current) result.push(current);
  return result.length > 0 ? result : [""];
}

// ---------------------------------------------------------------------------
// Main TUI
// ---------------------------------------------------------------------------

function die(msg) {
  console.error(`\n  Error: ${msg}\n`);
  process.exit(1);
}

function usage() {
  console.log("");
  console.log("  bd-plan-view - Browse beads plan trees in the terminal");
  console.log("");
  console.log("  Usage:");
  console.log("    bd-plan-view <bead-id>");
  console.log("    node bin/plan-view.js <bead-id>");
  console.log("");
  console.log("  Controls:");
  console.log("    Up/Down     Navigate tree");
  console.log("    Enter/Right Expand node");
  console.log("    Left        Collapse node");
  console.log("    q/Esc       Quit");
  console.log("");
}

function run(rootBeadId) {
  // Build tree
  process.stdout.write(`  Loading plan tree for ${rootBeadId}...`);
  const tree = buildTree(rootBeadId);
  process.stdout.write(" done.\n");

  let selectedIndex = 0;
  let detailScroll = 0;
  let running = true;

  // Enter raw mode
  if (!process.stdin.isTTY) {
    die("plan-view requires an interactive terminal (TTY).");
  }

  readline.emitKeypressEvents(process.stdin);
  process.stdin.setRawMode(true);
  process.stdin.resume();
  hideCursor();

  // Clean exit handler
  function cleanup() {
    showCursor();
    clearScreen();
    if (process.stdin.isTTY) {
      process.stdin.setRawMode(false);
    }
    process.stdin.pause();
  }

  process.on("exit", cleanup);
  process.on("SIGINT", () => {
    cleanup();
    process.exit(0);
  });
  process.on("SIGTERM", () => {
    cleanup();
    process.exit(0);
  });

  function render() {
    const { cols, rows } = getTermSize();
    const leftWidth = Math.floor(cols * 0.4);
    const rightWidth = cols - leftWidth - 1; // 1 for divider
    const contentHeight = Math.max(0, rows - 3); // header + footer

    const flatNodes = flattenTree(tree);

    // Clamp selection
    if (selectedIndex >= flatNodes.length) selectedIndex = flatNodes.length - 1;
    if (selectedIndex < 0) selectedIndex = 0;

    clearScreen();

    // Header bar
    moveCursor(1, 1);
    const header = `${C.bold}${C.bgBlue}${C.white}${padRight(
      "  bd-plan-view",
      cols
    )}${C.reset}`;
    process.stdout.write(header);

    // Subheader
    moveCursor(2, 1);
    const totalBeads = flatNodes.length;
    const closedBeads = flatNodes.filter((n) => n.status === "closed").length;
    const progress =
      totalBeads > 0 ? Math.round((closedBeads / totalBeads) * 100) : 0;
    const subheader = `${C.dim}  ${totalBeads} beads | ${closedBeads} closed (${progress}% done) | ${tree.id}${C.reset}`;
    process.stdout.write(padRight(subheader, cols));

    // Tree panel (left)
    const scrollStart = Math.max(
      0,
      Math.min(
        selectedIndex - Math.floor(contentHeight / 2),
        flatNodes.length - contentHeight
      )
    );

    for (let i = 0; i < contentHeight; i++) {
      const nodeIdx = scrollStart + i;
      const row = i + 3;
      moveCursor(row, 1);

      if (nodeIdx < flatNodes.length) {
        const node = flatNodes[nodeIdx];
        const isSelected = nodeIdx === selectedIndex;
        process.stdout.write(renderTreeLine(node, isSelected, leftWidth));
      } else {
        process.stdout.write(" ".repeat(leftWidth));
      }

      // Divider
      process.stdout.write(`${C.dim}\u2502${C.reset}`);
    }

    // Detail panel (right)
    const selectedNode = flatNodes[selectedIndex];
    if (selectedNode) {
      const detailLines = renderDetailPanel(
        selectedNode,
        rightWidth,
        Math.max(contentHeight * 4, 80) // generous buffer for scrolling long descriptions
      );

      // Clamp detail scroll
      const maxDetailScroll = Math.max(0, detailLines.length - contentHeight);
      if (detailScroll > maxDetailScroll) detailScroll = maxDetailScroll;
      if (detailScroll < 0) detailScroll = 0;

      for (let i = 0; i < contentHeight; i++) {
        const row = i + 3;
        moveCursor(row, leftWidth + 2);
        const lineIdx = detailScroll + i;
        if (lineIdx < detailLines.length) {
          process.stdout.write(
            truncate(padRight(detailLines[lineIdx], rightWidth), rightWidth)
          );
        } else {
          process.stdout.write(" ".repeat(rightWidth));
        }
      }
    }

    // Footer
    moveCursor(rows, 1);
    const footer = `${C.dim}  \u2191\u2193 navigate  \u2190\u2192/Enter expand/collapse  PgUp/PgDn detail scroll  q quit${C.reset}`;
    process.stdout.write(padRight(footer, cols));
  }

  // Key handler
  process.stdin.on("keypress", (str, key) => {
    if (!running) return;

    const flatNodes = flattenTree(tree);
    const { rows } = getTermSize();
    const contentHeight = rows - 3;

    if (key.name === "q" || (key.name === "escape")) {
      running = false;
      cleanup();
      process.exit(0);
    }

    if (key.ctrl && key.name === "c") {
      running = false;
      cleanup();
      process.exit(0);
    }

    if (key.name === "up") {
      selectedIndex = Math.max(0, selectedIndex - 1);
      detailScroll = 0;
      render();
    }

    if (key.name === "down") {
      selectedIndex = Math.min(flatNodes.length - 1, selectedIndex + 1);
      detailScroll = 0;
      render();
    }

    if (key.name === "return" || key.name === "right") {
      const node = flatNodes[selectedIndex];
      if (node && node.children.length > 0) {
        node.expanded = !node.expanded;
        render();
      }
    }

    if (key.name === "left") {
      const node = flatNodes[selectedIndex];
      if (node && node.expanded && node.children.length > 0) {
        node.expanded = false;
        render();
      } else if (node && node.depth > 0) {
        // Navigate to parent
        for (let i = selectedIndex - 1; i >= 0; i--) {
          if (flatNodes[i].depth < node.depth) {
            selectedIndex = i;
            break;
          }
        }
        render();
      }
    }

    // Page up/down for detail panel scroll
    if (key.name === "pageup" || (key.shift && key.name === "up")) {
      detailScroll = Math.max(0, detailScroll - contentHeight);
      render();
    }

    if (key.name === "pagedown" || (key.shift && key.name === "down")) {
      detailScroll += contentHeight;
      render();
    }
  });

  // Handle terminal resize
  process.stdout.on("resize", () => {
    if (running) render();
  });

  // Initial render
  render();
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

const args = process.argv.slice(2);

if (args.includes("--help") || args.includes("-h")) {
  usage();
  process.exit(0);
}

if (args.length === 0) {
  usage();
  die("Missing required argument: <bead-id>");
}

const beadId = args[0];
run(beadId);
