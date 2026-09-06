#!/usr/bin/env node

const { spawnSync } = require("node:child_process");
const { resolve } = require("node:path");

const root = resolve(__dirname, "..");
const [command = "install", ...args] = process.argv.slice(2);

function run(commandPath, commandArgs) {
  const result = spawnSync(commandPath, commandArgs, { cwd: root, stdio: "inherit" });
  process.exit(result.status ?? 1);
}

switch (command) {
  case "install":
    run("/bin/zsh", [resolve(root, "scripts/install.sh"), ...args]);
    break;
  case "uninstall":
    run("/bin/zsh", [resolve(root, "scripts/uninstall.sh")]);
    break;
  case "start":
    run("/bin/zsh", [resolve(root, "scripts/install.sh")]);
    break;
  case "help":
  case "--help":
  case "-h":
    console.log("Usage: agent-usage-menu [install [--claude] | start | uninstall]");
    break;
  default:
    console.error(`Unknown command: ${command}`);
    process.exit(64);
}
