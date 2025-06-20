#!pnpm tsx

import { execSync } from "child_process";
import { readdirSync, statSync } from "fs";
import { resolve, join } from "path";
import os from "os";

// Get CLI arguments
const args = process.argv.slice(2);

// Default directory
const defaultDir = resolve(os.homedir(), ".moon/lib/core/builtin");
const moonCommand = "moon run --target wasm-gc src/test";

// Utility to run the moon command
function runMoon(files: string[]) {
  const quotedFiles = files.map(f => `"${f}"`).join(" ");
  const fullCommand = `${moonCommand} ${quotedFiles}`;
  console.log(`Running: ${fullCommand}`);
  execSync(fullCommand, { stdio: "inherit" });
}

// Parse args
if (args.length === 0) {
  console.error("Usage: test.ts -d <directory>, or test.ts -t <file>");
  process.exit(1);
}

if (args[0] === "-d") {
  const dir = resolve(args[1] || defaultDir);
  let files: string[];

  try {
    files = readdirSync(dir)
      .map(f => join(dir, f))
      .filter(f => statSync(f).isFile());
  } catch (e) {
    console.error(`Error reading directory: ${dir}`);
    process.exit(1);
  }

  if (files.length === 0) {
    console.log("No files found in directory.");
    process.exit(0);
  }

  runMoon(files);
}

if (args[0] === "-t") {
  const file = args[1];
  if (!file) {
    console.error("Please provide a file name with -t");
    process.exit(1);
  }

  runMoon([resolve(file)]);
}

if (args[0] == "--ci") {
  execSync("python3 .github/scripts/ci_parser.py", { stdio: "inherit" });
}
