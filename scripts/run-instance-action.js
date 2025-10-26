#!/usr/bin/env node
"use strict";

import { spawnSync, spawn } from "node:child_process";

const ACTION_MAP = {
  ssh: { type: "ssh", command: ["gcloud", "compute", "ssh"] },
  stop: { type: "instance", command: ["gcloud", "compute", "instances", "stop"], quiet: true },
  start: { type: "instance", command: ["gcloud", "compute", "instances", "start"], quiet: true },
  suspend: { type: "instance", command: ["gcloud", "compute", "instances", "suspend"], quiet: true },
  resume: { type: "instance", command: ["gcloud", "compute", "instances", "resume"], quiet: true },
};

function exitWithMessage(message, code = 1) {
  console.error(message);
  process.exit(code);
}

function getActionAndArgs() {
  const [action, ...rest] = process.argv.slice(2);
  if (!ACTION_MAP[action]) {
    const supported = Object.keys(ACTION_MAP).join(", ");
    exitWithMessage(`Usage: node ${process.argv[1]} <${supported}> [additional gcloud args...]`);
  }
  return { action, extraArgs: rest };
}

function getTerraformOutputs() {
  const result = spawnSync("docker", ["compose", "run", "--rm", "terraform", "output", "-json"], {
    encoding: "utf8",
    stdio: ["inherit", "pipe", "inherit"],
  });

  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }

  try {
    return JSON.parse(result.stdout);
  } catch (err) {
    exitWithMessage(`Failed to parse terraform outputs: ${err.message}`);
  }
}

function pickOutput(outputs, key) {
  const entry = outputs[key];
  if (!entry) {
    exitWithMessage(`Terraform output "${key}" is missing. Did you run terraform apply?`);
  }
  if (typeof entry === "object" && Object.prototype.hasOwnProperty.call(entry, "value")) {
    return entry.value;
  }
  return entry;
}

function escapeShellArg(arg) {
  if (/^[a-zA-Z0-9._@%+=:,\/-]+$/.test(arg)) {
    return arg;
  }
  return `'${arg.replace(/'/g, `'\\''`)}'`;
}

function runGcloud(composeArgs, gcloudArgs) {
  const commandString = gcloudArgs.map(escapeShellArg).join(" ");
  console.log(commandString);
  const child = spawn("docker", [...composeArgs, commandString], { stdio: "inherit" });
  child.on("exit", (code, signal) => {
    if (typeof code === "number") {
      process.exit(code);
    }
    if (signal) {
      process.kill(process.pid, signal);
    } else {
      process.exit(1);
    }
  });
  child.on("error", (err) => {
    exitWithMessage(`Failed to execute docker compose: ${err.message}`);
  });
}

function main() {
  const { action, extraArgs } = getActionAndArgs();
  const outputs = getTerraformOutputs();

  const zone = pickOutput(outputs, "instance_zone");
  const project = pickOutput(outputs, "project_id");
  const name = pickOutput(outputs, "instance_name");

  const actionConfig = ACTION_MAP[action];
  const composeArgs = ["compose", "run", "--rm", "gcloud"];
  const gcloudArgs = [...actionConfig.command];

  if (actionConfig.type === "ssh") {
    gcloudArgs.push(name, "--project", project, "--zone", zone, ...extraArgs);
  } else {
    gcloudArgs.push(name, "--project", project, "--zone", zone);
    if (actionConfig.quiet) {
      gcloudArgs.push("--quiet");
    }
    gcloudArgs.push(...extraArgs);
  }

  runGcloud(composeArgs, gcloudArgs);
}

main();
