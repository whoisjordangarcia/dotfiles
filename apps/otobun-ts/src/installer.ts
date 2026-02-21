import fs from 'fs';
import path from 'path';
import {spawn} from 'child_process';
import {configToEnv} from './config.js';
import type {DotConfig} from './config.js';

export interface Component {
  name: string;
}

export function parseComponents(dotfilesDir: string, system: string): Component[] {
  const scriptPath = path.join(dotfilesDir, 'script', `${system}_installation.sh`);

  if (!fs.existsSync(scriptPath)) {
    return [];
  }

  const content = fs.readFileSync(scriptPath, 'utf-8');
  const match = content.match(/component_installation=\(([\s\S]*?)\)/);

  if (!match) return [];

  return match[1]
    .split('\n')
    .map(line => line.trim())
    .filter(line => line && !line.startsWith('#'))
    .map(line => line.replace(/#.*$/, '').trim())
    .filter(Boolean)
    .map(name => ({name}));
}

export interface RunResult {
  success: boolean;
  output: string;
  error?: string;
}

export function runComponent(
  dotfilesDir: string,
  component: Component,
  config: DotConfig,
  onOutput: (chunk: string) => void,
): Promise<RunResult> {
  return new Promise(resolve => {
    const scriptRelPath = `script/${component.name}/setup.sh`;
    const scriptAbsPath = path.join(dotfilesDir, scriptRelPath);

    if (!fs.existsSync(scriptAbsPath)) {
      const msg = `Script not found: ${scriptRelPath}\n`;
      onOutput(msg);
      resolve({success: false, output: msg, error: `Script not found: ${scriptRelPath}`});
      return;
    }

    const cmd = [
      'set -euo pipefail',
      `export SCRIPT_DIR='${path.join(dotfilesDir, 'script')}'`,
      `cd '${dotfilesDir}'`,
      `source ./script/common/log.sh`,
      `source ./script/common/symlink.sh`,
      `source ./script/${component.name}/setup.sh`,
    ].join('\n');

    const env: Record<string, string> = {
      ...(process.env as Record<string, string>),
      ...configToEnv(config),
    };

    const child = spawn('bash', ['-c', cmd], {cwd: dotfilesDir, env});

    let output = '';

    const handleData = (chunk: Buffer) => {
      const text = chunk.toString();
      output += text;
      onOutput(text);
    };

    child.stdout.on('data', handleData);
    child.stderr.on('data', handleData);

    child.on('close', code => {
      resolve({
        success: code === 0,
        output,
        error: code !== 0 ? `Process exited with code ${code}` : undefined,
      });
    });

    child.on('error', err => {
      resolve({success: false, output, error: err.message});
    });
  });
}
