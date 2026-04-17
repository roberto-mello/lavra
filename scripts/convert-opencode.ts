#!/usr/bin/env bun

/**
 * convert-opencode.ts
 * Converts lavra plugin files from Claude Code format to OpenCode format
 *
 * Security controls:
 * - Path traversal protection
 * - File size limits (10MB)
 * - YAML SAFE_SCHEMA parsing
 * - Model name validation
 * - Explicit file permissions (644)
 */

import { readdir, mkdir } from "node:fs/promises";
import { join } from "node:path";
import {
  validatePath,
  sanitizeFilename,
  readFileSafe,
  writeFileSafe,
  validateModelName,
  validateFilename,
} from "./shared/security";
import {
  parseFrontmatter,
  extractBody,
  buildMarkdown,
} from "./shared/yaml-parser";
import { mapToOpenCode } from "./shared/model-mapping";
import { mapColorToHex } from "./shared/color-mapping";
import {
  PLUGIN_VERSION,
  AGENT_CATEGORIES,
  generationHeader,
  convertSkills as sharedConvertSkills,
} from "./shared/conversion-utils";

const SOURCE_DIR = join(import.meta.dir, "../plugins/lavra");
const OUTPUT_DIR = join(import.meta.dir, "../plugins/lavra/opencode");

/**
 * Converts commands (direct copy - formats are identical)
 */
async function convertCommands() {
  console.log("Converting commands...");

  const commandsDir = validatePath(SOURCE_DIR, "commands");
  const outputDir = validatePath(OUTPUT_DIR, "commands");

  await mkdir(outputDir, { recursive: true, mode: 0o755 });

  const files = await readdir(commandsDir);
  const mdFiles = files.filter((f) => f.endsWith(".md"));

  // Parallel processing for performance
  await Promise.all(
    mdFiles.map(async (file) => {
      if (!validateFilename(file)) {
        console.warn(`  ⚠️  Skipping invalid filename: ${file}`);
        return;
      }

      const sourcePath = validatePath(commandsDir, file);
      const outputPath = validatePath(outputDir, sanitizeFilename(file));

      const raw = await readFileSafe(sourcePath);
      const content = raw
        .replace(/\.claude\/skills\//g, ".opencode/skills/")
        .replace(/ls \.claude\/skills\//g, "ls .opencode/skills/");

      const withHeader = generationHeader(file) + content;

      await writeFileSafe(outputPath, withHeader, 0o644);
      console.log(`  ✓ ${file}`);
    })
  );

  console.log(`  Converted ${mdFiles.length} commands\n`);
}

/**
 * Converts agents (field mapping required)
 */
async function convertAgents() {
  console.log("Converting agents...");

  const categories = AGENT_CATEGORIES;
  let totalConverted = 0;

  // Create all category directories upfront
  await Promise.all(
    categories.map((category) =>
      mkdir(join(OUTPUT_DIR, "agents", category), {
        recursive: true,
        mode: 0o755,
      })
    )
  );

  // Process each category in parallel
  await Promise.all(
    categories.map(async (category) => {
      const categoryDir = validatePath(SOURCE_DIR, `agents/${category}`);
      const outputCategoryDir = validatePath(OUTPUT_DIR, `agents/${category}`);

      const files = await readdir(categoryDir);
      const mdFiles = files.filter((f) => f.endsWith(".md"));

      // Process files in parallel
      await Promise.all(
        mdFiles.map(async (file) => {
          if (!validateFilename(file)) {
            console.warn(`  ⚠️  Skipping invalid filename: ${file}`);
            return;
          }

          const sourcePath = validatePath(categoryDir, file);
          const outputPath = validatePath(outputCategoryDir, sanitizeFilename(file));

          const content = await readFileSafe(sourcePath);
          const frontmatter = parseFrontmatter(content);
          const body = extractBody(content);

          // Transform frontmatter for OpenCode
          const opencodeFrontmatter: Record<string, any> = {
            description: frontmatter.description || "",
            mode: "subagent",
          };

          const mappedColor = frontmatter.color && mapColorToHex(frontmatter.color);
          if (mappedColor) opencodeFrontmatter.color = mappedColor;

          // Map model if present and not inherit
          if (frontmatter.model && frontmatter.model !== "inherit") {
            const mappedModel = mapToOpenCode(frontmatter.model);
            validateModelName(mappedModel);
            opencodeFrontmatter.model = mappedModel;
          } else {
            opencodeFrontmatter.model = "inherit";
          }

          const output = buildMarkdown(opencodeFrontmatter, body);
          const withHeader = generationHeader(`${category}/${file}`) + output;

          await writeFileSafe(outputPath, withHeader, 0o644);
          console.log(`  ✓ ${category}/${file}`);
        })
      );

      totalConverted += mdFiles.length;
    })
  );

  console.log(`  Converted ${totalConverted} agents\n`);
}

async function convertSkills() {
  await sharedConvertSkills(SOURCE_DIR, OUTPUT_DIR, ".opencode/skills/");
}

/**
 * Generates documentation about MCP server configuration
 */
async function generateMCPDocs() {
  console.log("Generating MCP configuration docs...");

  const docsDir = validatePath(OUTPUT_DIR, "docs");
  await mkdir(docsDir, { recursive: true, mode: 0o755 });

  const mcpDocs = `# MCP Server Configuration for OpenCode

The lavra plugin uses the Context7 MCP server for framework documentation.

## Manual Configuration Required

OpenCode does not support automatic MCP server installation. You need to manually add the server to your OpenCode configuration.

### Configuration File

Add to \`~/.config/opencode/config.json\` or your project's \`opencode.json\`:

\`\`\`json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upwithcrowd/context7-mcp@latest"],
      "env": {}
    }
  }
}
\`\`\`

### What Context7 Provides

- Semantic search across PostgreSQL and TimescaleDB documentation
- Framework-specific best practices and patterns
- API reference lookups

### Usage in OpenCode

Once configured, agents can use the Context7 tools to search documentation:

\`\`\`typescript
// Example: Search PostgreSQL docs
await mcp.call("context7", "search_docs", {
  source: "postgres",
  search_type: "semantic",
  query: "create hypertable with compression",
  version: "latest",
  limit: 5
});
\`\`\`

## Security Note

The Context7 MCP server runs as a subprocess with access to your environment. Only install if you trust the source.
`;

  const docsPath = join(docsDir, "MCP_SETUP.md");
  await writeFileSafe(docsPath, mcpDocs, 0o644);

  console.log(`  ✓ Generated MCP_SETUP.md\n`);
}

/**
 * Main conversion function
 */
async function main() {
  console.log("🔄 Converting lavra to OpenCode format\n");
  console.log(`Source: ${SOURCE_DIR}`);
  console.log(`Output: ${OUTPUT_DIR}\n`);

  try {
    // Create root output directory
    await mkdir(OUTPUT_DIR, { recursive: true, mode: 0o755 });

    // Run all conversions in parallel
    await Promise.all([
      convertCommands(),
      convertAgents(),
      convertSkills(),
      generateMCPDocs(),
    ]);

    console.log("✅ Conversion complete!");
    console.log(`\nGenerated files in: ${OUTPUT_DIR}`);

    // Only show manual copy instructions if running standalone (not during install)
    if (!process.env.LAVRA_INSTALLING) {
      console.log("\nNext steps:");
      console.log("1. Review the generated files");
      console.log("2. Copy to your OpenCode project:");
      console.log(`   cp -r ${OUTPUT_DIR}/* <project>/.opencode/`);
      console.log("3. Configure MCP servers (see opencode/docs/MCP_SETUP.md)");
    }
  } catch (err: any) {
    console.error("❌ Conversion failed:", err.message);
    process.exit(1);
  }
}

// Run if executed directly
if (import.meta.main) {
  main();
}

export { convertCommands, convertAgents, convertSkills };
