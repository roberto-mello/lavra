/**
 * Color name to hex mapping for platform conversions
 * Claude Code accepts named colors; OpenCode and Gemini require hex values
 */

export const COLOR_MAP: Record<string, string> = {
  red: "#EF4444",
  blue: "#3B82F6",
  green: "#22C55E",
  yellow: "#EAB308",
  purple: "#A855F7",
  orange: "#F97316",
  pink: "#EC4899",
  cyan: "#06B6D4",
  teal: "#14B8A6",
  gray: "#6B7280",
  violet: "#8B5CF6",
};

/**
 * Maps a named color to its hex equivalent.
 * Returns undefined if the color is unknown or already a hex value.
 */
export function mapColorToHex(color: string): string | undefined {
  if (color.startsWith("#")) return color;
  return COLOR_MAP[color.toLowerCase()];
}
