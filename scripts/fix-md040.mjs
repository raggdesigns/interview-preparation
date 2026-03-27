#!/usr/bin/env node
// Adds "text" language to bare fenced code block openings (MD040 fix)
// Correctly distinguishes opening fences from closing fences via state tracking

import { readFileSync, writeFileSync, readdirSync, statSync } from "fs";
import { join } from "path";

function findMarkdownFiles(dir, files = []) {
  for (const entry of readdirSync(dir)) {
    if (entry === "node_modules" || entry.startsWith(".")) continue;
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) {
      findMarkdownFiles(full, files);
    } else if (entry.endsWith(".md")) {
      files.push(full);
    }
  }
  return files;
}

const mdFiles = findMarkdownFiles(".");
let fixed = 0;

for (const file of mdFiles) {
  const original = readFileSync(file, "utf8");
  const lines = original.split("\n");
  let insideFence = false;
  let changed = false;

  const result = lines.map((line) => {
    // Closing or opening fence with no language
    const bareFence = line.match(/^(\s*)(`{3,}|~{3,})\s*$/);
    if (bareFence) {
      if (!insideFence) {
        insideFence = true;
        changed = true;
        return bareFence[1] + bareFence[2] + "text";
      } else {
        insideFence = false;
        return line;
      }
    }
    // Opening fence with a language already specified
    if (!insideFence && line.match(/^(\s*)(`{3,}|~{3,})\S/)) {
      insideFence = true;
    }
    return line;
  });

  if (changed) {
    writeFileSync(file, result.join("\n"), "utf8");
    fixed++;
    console.log(`fixed: ${file}`);
  }
}

console.log(`\nMD040: added language specifier to bare fences in ${fixed} file(s)`);
