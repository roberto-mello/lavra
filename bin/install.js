#!/usr/bin/env node

"use strict";

const { execSync, spawn } = require("child_process");
const fs = require("fs");
const path = require("path");
const readline = require("readline");

// ---------------------------------------------------------------------------
// Paths
// ---------------------------------------------------------------------------

const PKG_ROOT = path.resolve(__dirname, "..");
const INSTALL_SH = path.join(PKG_ROOT, "install.sh");
const UNINSTALL_SH = path.join(PKG_ROOT, "uninstall.sh");
const PKG_JSON = path.join(PKG_ROOT, "package.json");

// ---------------------------------------------------------------------------
// Version
// ---------------------------------------------------------------------------

function getVersion() {
  try {
    const pkg = JSON.parse(fs.readFileSync(PKG_JSON, "utf8"));
    return pkg.version || "unknown";
  } catch {
    return "unknown";
  }
}

const VERSION = getVersion();

// ---------------------------------------------------------------------------
// CLI argument parsing
// ---------------------------------------------------------------------------

const args = process.argv.slice(2);

const FLAG = {
  claude: args.includes("--claude"),
  opencode: args.includes("--opencode"),
  gemini: args.includes("--gemini"),
  global: args.includes("--global"),
  local: args.includes("--local"),
  uninstall: args.includes("--uninstall"),
  yes: args.includes("--yes") || args.includes("-y"),
  help: args.includes("--help") || args.includes("-h"),
};

// Positional argument: optional target directory path
const _positional = args.find((a) => !a.startsWith("-"));
const TARGET_PATH = _positional ? path.resolve(_positional) : null;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function banner() {
  console.log("");
  console.log(`  lavra v${VERSION}`);
  console.log("  Persistent memory + multi-agent workflows");
  console.log("");
}

function usage() {
  banner();
  console.log("  Usage:");
  console.log("    npx lavra@latest                Interactive installer");
  console.log("    npx lavra@latest --claude       Claude Code (local project)");
  console.log("    npx lavra@latest --opencode     OpenCode (local project)");
  console.log("    npx lavra@latest --gemini       Gemini CLI (local project)");
  console.log("    npx lavra@latest --global       Install globally (~/.claude/)");
  console.log("    npx lavra@latest --uninstall    Uninstall from current project");
  console.log("    npx lavra@latest --yes          Skip confirmation prompts");
  console.log("");
  console.log("  Flags can be combined:");
  console.log("    npx lavra@latest --opencode --yes");
  console.log("    npx lavra@latest --claude --global");
  console.log("");
}

function die(msg) {
  console.error(`\n  Error: ${msg}\n`);
  process.exit(1);
}

function ensureBash() {
  try {
    execSync("bash --version", { stdio: "ignore" });
  } catch {
    die("bash is required but was not found on your system.");
  }
}

function ensureScript(scriptPath, label) {
  if (!fs.existsSync(scriptPath)) {
    die(`${label} not found at ${scriptPath}. The package may be corrupted.`);
  }
}

// ---------------------------------------------------------------------------
// Interactive prompts
// ---------------------------------------------------------------------------

function createRL() {
  return readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
}

function ask(rl, question) {
  return new Promise((resolve) => {
    rl.question(question, (answer) => resolve(answer.trim()));
  });
}

async function promptRuntime(rl) {
  console.log("  Select runtime:");
  console.log("  1. Claude Code");
  console.log("  2. OpenCode");
  console.log("  3. Gemini CLI");
  console.log("");

  while (true) {
    const answer = await ask(rl, "  > ");
    switch (answer) {
      case "1": return "claude";
      case "2": return "opencode";
      case "3": return "gemini";
      default:
        console.log("  Please enter 1, 2, or 3.");
    }
  }
}

async function promptScope(rl) {
  console.log("");
  console.log("  Install scope:");
  console.log("  1. This project (current directory)");
  console.log("  2. Global (~/.claude/)");
  console.log("");

  while (true) {
    const answer = await ask(rl, "  > ");
    switch (answer) {
      case "1": return "local";
      case "2": return "global";
      default:
        console.log("  Please enter 1 or 2.");
    }
  }
}

async function promptUninstallOrInstall(rl) {
  console.log("  Action:");
  console.log("  1. Install");
  console.log("  2. Uninstall");
  console.log("");

  while (true) {
    const answer = await ask(rl, "  > ");
    switch (answer) {
      case "1": return "install";
      case "2": return "uninstall";
      default:
        console.log("  Please enter 1 or 2.");
    }
  }
}

// ---------------------------------------------------------------------------
// Execution
// ---------------------------------------------------------------------------

function runScript(scriptPath, scriptArgs) {
  return new Promise((resolve, reject) => {
    const child = spawn("bash", [scriptPath, ...scriptArgs], {
      stdio: "inherit",
      cwd: process.cwd(),
    });

    child.on("error", (err) => {
      reject(new Error(`Failed to start bash: ${err.message}`));
    });

    child.on("close", (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`Script exited with code ${code}`));
      }
    });
  });
}

function buildInstallArgs(runtime, scope) {
  const scriptArgs = [];

  // Runtime flag
  if (runtime === "opencode") scriptArgs.push("-opencode");
  if (runtime === "gemini") scriptArgs.push("-gemini");
  // Claude Code is the default — no flag needed

  // --yes passthrough
  if (FLAG.yes) scriptArgs.push("--yes");

  // Target directory
  // For global: pass no path — install.sh defaults to ~/.claude and sets GLOBAL_INSTALL=true
  // Passing ~/.claude explicitly would be treated as a local install, breaking bd init skip
  if (scope !== "global") {
    scriptArgs.push(TARGET_PATH || process.cwd());
  }

  return scriptArgs;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  if (FLAG.help) {
    usage();
    process.exit(0);
  }

  ensureBash();
  banner();

  // --- Uninstall path ---
  if (FLAG.uninstall) {
    ensureScript(UNINSTALL_SH, "uninstall.sh");
    const target = TARGET_PATH || process.cwd();
    console.log(`  Uninstalling lavra from ${target}...\n`);
    try {
      await runScript(UNINSTALL_SH, [target]);
      console.log("\n  Uninstall complete.\n");
    } catch (err) {
      die(err.message);
    }
    return;
  }

  ensureScript(INSTALL_SH, "install.sh");

  // Determine runtime
  let runtime;
  const runtimeFlags = [FLAG.claude, FLAG.opencode, FLAG.gemini].filter(Boolean).length;
  if (runtimeFlags > 1) {
    die("Specify only one runtime: --claude, --opencode, or --gemini");
  }

  if (FLAG.claude) runtime = "claude";
  else if (FLAG.opencode) runtime = "opencode";
  else if (FLAG.gemini) runtime = "gemini";

  // Determine scope
  let scope;
  if (FLAG.global && FLAG.local) {
    die("Specify only one scope: --global or --local");
  }
  if (FLAG.global) scope = "global";
  else if (FLAG.local) scope = "local";
  else if (TARGET_PATH) scope = "local"; // path argument implies local
  else if (FLAG.yes) scope = "local";   // --yes with no scope defaults to local

  // Interactive prompts if needed
  if (!runtime || !scope) {
    const rl = createRL();
    try {
      if (!runtime) {
        runtime = await promptRuntime(rl);
        console.log("");
      }
      if (!scope) {
        scope = await promptScope(rl);
        console.log("");
      }
    } finally {
      rl.close();
    }
  }

  // Build args and run
  const scriptArgs = buildInstallArgs(runtime, scope);
  const runtimeLabel = {
    claude: "Claude Code",
    opencode: "OpenCode",
    gemini: "Gemini CLI",
  }[runtime];
  const scopeLabel = scope === "global" ? "globally" : "in current project";

  console.log(`  Installing lavra for ${runtimeLabel} ${scopeLabel}...\n`);

  try {
    await runScript(INSTALL_SH, scriptArgs);
    console.log("\n  Done!\n");
  } catch (err) {
    die(err.message);
  }
}

main().catch((err) => {
  die(err.message);
});
