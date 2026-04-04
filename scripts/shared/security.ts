import { resolve, relative } from "node:path";
import { stat, chmod } from "node:fs/promises";

/**
 * Security configuration constants
 */
export const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB
export const ALLOWED_FILE_PATTERN = /^[a-zA-Z0-9._-]+\.md$/;
// Model name format: alphanumeric + hyphen + slash + dot (e.g. "anthropic/claude-opus-4-6")
// No allowlist — users can select any model from their provider.
// The format regex in validateModelName() prevents injection.

/**
 * Validates that a path does not escape the base directory
 * Prevents path traversal attacks like ../../../etc/passwd
 */
export function validatePath(basePath: string, targetPath: string): string {
  const resolved = resolve(basePath, targetPath);
  const rel = relative(basePath, resolved);

  if (rel.startsWith("..") || resolve(basePath, rel) !== resolved) {
    throw new Error(`Path traversal detected: ${targetPath}`);
  }

  return resolved;
}

/**
 * Sanitizes a filename to prevent malicious characters
 * Allows only alphanumeric, dots, underscores, and hyphens
 */
export function sanitizeFilename(filename: string): string {
  return filename.replace(/[^a-zA-Z0-9._-]/g, "_");
}

/**
 * Reads a file safely with size limit enforcement
 */
export async function readFileSafe(path: string): Promise<string> {
  const stats = await stat(path);

  if (stats.size > MAX_FILE_SIZE) {
    throw new Error(
      `File too large: ${path} (${stats.size} bytes, max ${MAX_FILE_SIZE})`
    );
  }

  const file = Bun.file(path);
  return await file.text();
}

/**
 * Writes a file with explicit permissions
 * Ensures files are not world-writable
 */
export async function writeFileSafe(
  path: string,
  content: string,
  mode: number = 0o644
): Promise<void> {
  await Bun.write(path, content);
  await chmod(path, mode);
}

/**
 * Validates a model name against allowlist
 * Prevents injection via model field
 */
export function validateModelName(modelName: string): string {
  // Strict alphanumeric + hyphen + slash + dot + colon validation
  // Prevents injection — model names go into frontmatter, not shell commands
  if (!/^[a-z0-9/.:-]+$/i.test(modelName) || modelName.includes("..")) {
    throw new Error(`Invalid model name format: ${modelName}`);
  }

  return modelName;
}

/**
 * Validates a filename matches allowed pattern
 */
export function validateFilename(filename: string): boolean {
  return ALLOWED_FILE_PATTERN.test(filename);
}
