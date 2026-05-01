#!/usr/bin/env bun

/**
 * convert-codex.ts
 * Builds Codex-specific artifacts from cortex conversion output and rewrites
 * AskUserQuestion references to Codex-compatible direct prompt instructions.
 */

import { spawn } from "node:child_process";
import { mkdir, readdir, readFile, rm, stat, writeFile, cp } from "node:fs/promises";
import { join } from "node:path";

const ROOT = join(import.meta.dir, "..");
const CORTEX_DIR = join(ROOT, "plugins/lavra/cortex");
const CODEX_DIR = join(ROOT, "plugins/lavra/codex");

async function runConvertCortex(): Promise<void> {
  await new Promise<void>((resolve, reject) => {
    const child = spawn("bun", ["run", "convert-cortex.ts"], {
      cwd: import.meta.dir,
      stdio: "inherit",
      env: process.env,
    });
    child.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`convert-cortex.ts failed with code ${code}`));
    });
    child.on("error", reject);
  });
}

function rewriteAskUserQuestion(content: string): string {
  let out = content;

  out = out.replace(
    /Use\s+\*\*AskUserQuestion tool\*\*\s*to/gi,
    "Ask user directly in chat (Codex-compatible) to"
  );
  out = out.replace(/Use\s+AskUserQuestion\s*tool\s*to/gi, "Ask user directly in chat (Codex-compatible) to");
  out = out.replace(/Use\s+AskUserQuestion\s*:/gi, "Ask user directly in chat (Codex-compatible):");
  out = out.replace(/AskUserQuestion tool/gi, "direct user prompt");
  out = out.replace(/AskUserQuestion/gi, "direct user prompt");

  // Add a concise compatibility note once per file if any rewrite happened.
  if (out !== content && !out.includes("Codex note: request_user_input may be unavailable")) {
    out += "\n\nCodex note: request_user_input may be unavailable in Default mode. Use direct chat questions with a recommended default when safe.\n";
  }

  return out;
}

async function walk(dir: string, out: string[] = []): Promise<string[]> {
  const entries = await readdir(dir, { withFileTypes: true });
  for (const entry of entries) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      await walk(full, out);
    } else {
      out.push(full);
    }
  }
  return out;
}

async function transformCodexFiles(): Promise<void> {
  const files = await walk(CODEX_DIR);
  for (const file of files) {
    if (!file.endsWith(".md")) continue;
    const raw = await readFile(file, "utf8");
    let next = raw
      .replace(/\.cortex\/skills\//g, ".codex/skills/")
      .replace(/ls \.cortex\/skills\//g, "ls .codex/skills/")
      .replace(/\.cortex\/hooks\//g, ".codex/hooks/");
    next = rewriteAskUserQuestion(next);
    await writeFile(file, next, "utf8");
  }
}

async function assertNoAskUserQuestion(): Promise<void> {
  const files = await walk(CODEX_DIR);
  const offenders: string[] = [];
  for (const file of files) {
    if (!file.endsWith(".md")) continue;
    const raw = await readFile(file, "utf8");
    if (/AskUserQuestion/i.test(raw)) {
      offenders.push(file.replace(`${ROOT}/`, ""));
    }
  }
  if (offenders.length > 0) {
    throw new Error(
      `Codex conversion left AskUserQuestion references in ${offenders.length} file(s):\n` +
        offenders.slice(0, 20).join("\n")
    );
  }
}

async function main() {
  console.log("🔄 Building Codex artifacts\n");
  await runConvertCortex();

  // Rebuild codex output from cortex output to keep behavior in sync.
  await rm(CODEX_DIR, { recursive: true, force: true });
  await mkdir(CODEX_DIR, { recursive: true, mode: 0o755 });
  await cp(CORTEX_DIR, CODEX_DIR, { recursive: true });

  await transformCodexFiles();
  await assertNoAskUserQuestion();

  // basic existence check
  await stat(join(CODEX_DIR, "commands"));
  await stat(join(CODEX_DIR, "skills"));
  await stat(join(CODEX_DIR, "agents"));

  console.log("✅ Codex conversion complete");
  console.log(`Output: ${CODEX_DIR}`);
}

main().catch((err) => {
  console.error("❌ convert-codex failed:", err.message);
  process.exit(1);
});

