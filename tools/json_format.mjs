// Compact, readable JSON for the data files (2026-11-27): tab-indented like before, but any
// array or object that fits on one line (up to WIDTH characters, indentation included) is
// written on one line. A zone's piece is then one line instead of eleven.
//   node tools/json_format.mjs <file.json> [...]   rewrites the files in place
// The generators in tools/art use formatJson when they write their tables.
import fs from "node:fs";
import { fileURLToPath } from "node:url";

const WIDTH = 140;

function inline(v) {
  if (Array.isArray(v)) return "[" + v.map(inline).join(", ") + "]";
  if (v !== null && typeof v === "object") return "{" + Object.entries(v).map(([k, x]) => JSON.stringify(k) + ": " + inline(x)).join(", ") + "}";
  return JSON.stringify(v);
}

function block(v, depth) {
  const pad = "\t".repeat(depth);
  const one = inline(v);
  if (v === null || typeof v !== "object" || pad.length * 4 + one.length <= WIDTH) return one;
  const inner = "\t".repeat(depth + 1);
  if (Array.isArray(v)) {
    if (v.length === 0) return "[]";
    return "[\n" + v.map((x) => inner + block(x, depth + 1)).join(",\n") + "\n" + pad + "]";
  }
  const entries = Object.entries(v);
  if (entries.length === 0) return "{}";
  return "{\n" + entries.map(([k, x]) => inner + JSON.stringify(k) + ": " + block(x, depth + 1)).join(",\n") + "\n" + pad + "}";
}

export function formatJson(value) {
  return block(value, 0) + "\n";
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  for (const path of process.argv.slice(2)) {
    const before = fs.readFileSync(path, "utf8");
    const value = JSON.parse(before);
    const after = formatJson(value);
    if (JSON.stringify(JSON.parse(after)) !== JSON.stringify(value)) throw new Error("format changed the data of " + path);
    if (after !== before) fs.writeFileSync(path, after);
  }
}
