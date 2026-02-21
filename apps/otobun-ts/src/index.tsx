#!/usr/bin/env node
import React from 'react';
import {render} from 'ink';
import fs from 'fs';
import path from 'path';
import {fileURLToPath} from 'url';
import {App} from './tui/App.js';
import {configExists, loadConfig} from './config.js';
import {detectSystem} from './detector.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname  = path.dirname(__filename);

/** Walk up from the current file until we find the dotfiles root (has a script/ dir). */
function findDotfilesDir(): string {
  let dir = __dirname;
  while (true) {
    if (fs.existsSync(path.join(dir, 'script'))) return dir;
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return process.cwd();
}

function showHelp(): void {
  console.log(`
Usage: otobun [options]

Options:
  --setup, -s    Force setup wizard (even if .dotconfig exists)
  --config, -c   Show current configuration
  --system       Show detected system
  --help, -h     Show this help

Examples:
  otobun              Full TUI: wizard → module selector → installer
  otobun --setup      Force re-run setup wizard
  otobun --config     Print current .dotconfig values
  otobun --system     Print detected OS/distro/system
`);
}

function showConfig(dotfilesDir: string): void {
  if (!configExists(dotfilesDir)) {
    console.log('No configuration found. Run otobun to set up.');
    return;
  }
  const cfg = loadConfig(dotfilesDir);
  console.log('Current configuration:');
  console.log(`  Name:        ${cfg.name}`);
  console.log(`  Email:       ${cfg.email}`);
  console.log(`  Environment: ${cfg.environment}`);
  console.log(`  System:      ${cfg.system}`);
  if (cfg.yubiKey) console.log(`  YubiKey:     ${cfg.yubiKey}`);
}

function showSystem(): void {
  const sys = detectSystem();
  console.log('Detected system:');
  console.log(`  OS:     ${sys.os}`);
  console.log(`  Distro: ${sys.distro || '(none)'}`);
  console.log(`  System: ${sys.system}`);
}

const args = process.argv.slice(2);
const dotfilesDir = findDotfilesDir();

if (args.includes('--help') || args.includes('-h')) {
  showHelp();
  process.exit(0);
}

if (args.includes('--config') || args.includes('-c')) {
  showConfig(dotfilesDir);
  process.exit(0);
}

if (args.includes('--system')) {
  showSystem();
  process.exit(0);
}

const forceSetup = args.includes('--setup') || args.includes('-s');

const {waitUntilExit} = render(
  <App dotfilesDir={dotfilesDir} forceSetup={forceSetup} />,
);

waitUntilExit().then(() => process.exit(0));
