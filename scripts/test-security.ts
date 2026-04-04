#!/usr/bin/env bun

/**
 * Security controls test suite
 * Tests path traversal, file size limits, YAML parsing, and other security controls
 */

import { mkdir, writeFile, rm } from "node:fs/promises";
import { join } from "node:path";
import {
  validatePath,
  sanitizeFilename,
  validateModelName,
  readFileSafe,
} from "./shared/security";
import { parseFrontmatter } from "./shared/yaml-parser";

const TEST_DIR = join(import.meta.dir, "../test-output");
const PASSED: string[] = [];
const FAILED: string[] = [];

function pass(name: string) {
  PASSED.push(name);
  console.log(`✓ ${name}`);
}

function fail(name: string, error: string) {
  FAILED.push(name);
  console.log(`✗ ${name}: ${error}`);
}

async function testPathTraversal() {
  console.log("\n🔒 Testing path traversal protection...");

  // Test 1: Valid path should work
  try {
    const valid = validatePath(TEST_DIR, "test.md");
    if (valid.includes(TEST_DIR)) {
      pass("Valid path accepted");
    } else {
      fail("Valid path", "Path validation returned unexpected result");
    }
  } catch (err: any) {
    fail("Valid path", err.message);
  }

  // Test 2: Path traversal should be rejected
  try {
    validatePath(TEST_DIR, "../../../etc/passwd");
    fail("Path traversal", "Should have thrown error");
  } catch (err: any) {
    if (err.message.includes("Path traversal detected")) {
      pass("Path traversal rejected");
    } else {
      fail("Path traversal", `Wrong error: ${err.message}`);
    }
  }

  // Test 3: Symlink-style path should be rejected
  try {
    validatePath(TEST_DIR, "../../sensitive/data");
    fail("Symlink path", "Should have thrown error");
  } catch (err: any) {
    if (err.message.includes("Path traversal detected")) {
      pass("Symlink path rejected");
    } else {
      fail("Symlink path", `Wrong error: ${err.message}`);
    }
  }
}

async function testFilenameSanitization() {
  console.log("\n🧹 Testing filename sanitization...");

  // Test 1: Valid filename unchanged
  const valid = sanitizeFilename("test-file_v2.md");
  if (valid === "test-file_v2.md") {
    pass("Valid filename unchanged");
  } else {
    fail("Valid filename", `Expected test-file_v2.md, got ${valid}`);
  }

  // Test 2: Special characters removed
  const malicious = sanitizeFilename("../../../etc/passwd");
  if (malicious === ".._.._.._etc_passwd") {
    pass("Special characters sanitized");
  } else {
    fail("Special characters", `Expected .._.._.._etc_passwd, got ${malicious}`);
  }

  // Test 3: Spaces converted
  const spaces = sanitizeFilename("file with spaces.md");
  if (spaces === "file_with_spaces.md") {
    pass("Spaces converted to underscores");
  } else {
    fail("Spaces", `Expected file_with_spaces.md, got ${spaces}`);
  }
}

async function testFileSizeLimit() {
  console.log("\n📏 Testing file size limits...");

  await mkdir(TEST_DIR, { recursive: true, mode: 0o755 });

  // Test 1: Small file accepted
  const smallFile = join(TEST_DIR, "small.md");
  await writeFile(smallFile, "# Small file\n\nContent here.");

  try {
    const content = await readFileSafe(smallFile);
    if (content.includes("Small file")) {
      pass("Small file accepted");
    } else {
      fail("Small file", "Content not read correctly");
    }
  } catch (err: any) {
    fail("Small file", err.message);
  }

  // Test 2: Large file rejected (create 11MB file)
  const largeFile = join(TEST_DIR, "large.md");
  const largeContent = "x".repeat(11 * 1024 * 1024); // 11MB
  await writeFile(largeFile, largeContent);

  try {
    await readFileSafe(largeFile);
    fail("Large file", "Should have thrown size limit error");
  } catch (err: any) {
    if (err.message.includes("File too large")) {
      pass("Large file rejected (>10MB)");
    } else {
      fail("Large file", `Wrong error: ${err.message}`);
    }
  }

  // Cleanup
  await rm(TEST_DIR, { recursive: true, force: true });
}

async function testModelNameValidation() {
  console.log("\n🎯 Testing model name validation...");

  // Test 1: Valid model names accepted
  const validModels = [
    "sonnet",
    "opus",
    "haiku",
    "inherit",
    "anthropic/claude-sonnet-4-20250514",
    "gemini-2.5-pro",
  ];

  for (const model of validModels) {
    try {
      const result = validateModelName(model);
      if (result === model) {
        pass(`Valid model accepted: ${model}`);
      } else {
        fail(`Valid model: ${model}`, `Expected ${model}, got ${result}`);
      }
    } catch (err: any) {
      fail(`Valid model: ${model}`, err.message);
    }
  }

  // Test 2: Invalid model names rejected
  const invalidModels = [
    "; rm -rf /",
    "../../../etc/passwd",
    "$(whoami)",
    "malicious' OR '1'='1",
  ];

  for (const model of invalidModels) {
    try {
      validateModelName(model);
      fail(`Invalid model: ${model}`, "Should have thrown error");
    } catch (err: any) {
      if (err.message.includes("Invalid model name format")) {
        pass(`Invalid model rejected: ${model}`);
      } else {
        fail(`Invalid model: ${model}`, `Wrong error: ${err.message}`);
      }
    }
  }
}

async function testYAMLParsing() {
  console.log("\n📝 Testing YAML parsing security...");

  // Test 1: Valid YAML accepted
  const validYAML = `---
name: test-agent
description: Test agent description
model: sonnet
---
Body content here`;

  try {
    const parsed = parseFrontmatter(validYAML);
    if (parsed.name === "test-agent" && parsed.model === "sonnet") {
      pass("Valid YAML parsed correctly");
    } else {
      fail("Valid YAML", "Parsed values incorrect");
    }
  } catch (err: any) {
    fail("Valid YAML", err.message);
  }

  // Test 2: Malicious YAML rejected (code execution attempt)
  const maliciousYAML = `---
!!python/object/apply:os.system
args: ['echo pwned']
---
Body`;

  try {
    parseFrontmatter(maliciousYAML);
    fail("Malicious YAML", "Should have thrown error on unsafe tag");
  } catch (err: any) {
    if (err.message.includes("parse error") || err.message.toLowerCase().includes("unknown tag")) {
      pass("Malicious YAML rejected (code execution blocked)");
    } else {
      fail("Malicious YAML", `Wrong error: ${err.message}`);
    }
  }

  // Test 3: Invalid structure rejected
  const invalidYAML = `---
this is not valid yaml at all!!!
---
Body`;

  try {
    parseFrontmatter(invalidYAML);
    fail("Invalid YAML", "Should have thrown parse error");
  } catch (err: any) {
    if (err.message.includes("parse error")) {
      pass("Invalid YAML rejected");
    } else {
      fail("Invalid YAML", `Wrong error: ${err.message}`);
    }
  }
}

async function main() {
  console.log("🛡️  Security Controls Test Suite\n");
  console.log("Testing lavra conversion script security...\n");

  await testPathTraversal();
  await testFilenameSanitization();
  await testFileSizeLimit();
  await testModelNameValidation();
  await testYAMLParsing();

  console.log("\n" + "=".repeat(60));
  console.log(`✓ Passed: ${PASSED.length}`);
  console.log(`✗ Failed: ${FAILED.length}`);
  console.log("=".repeat(60));

  if (FAILED.length > 0) {
    console.log("\n❌ Some tests failed:");
    FAILED.forEach((test) => console.log(`  - ${test}`));
    process.exit(1);
  } else {
    console.log("\n✅ All security tests passed!");
  }
}

if (import.meta.main) {
  main();
}
