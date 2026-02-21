import fs from 'fs';
import path from 'path';

export interface DotConfig {
  name: string;
  email: string;
  environment: 'work' | 'personal';
  system: string;
  yubiKey: string;
}

const CONFIG_FILE = '.dotconfig';

export function configExists(dotfilesDir: string): boolean {
  return fs.existsSync(path.join(dotfilesDir, CONFIG_FILE));
}

export function loadConfig(dotfilesDir: string): DotConfig {
  const filePath = path.join(dotfilesDir, CONFIG_FILE);
  const content = fs.readFileSync(filePath, 'utf-8');

  const config: Partial<DotConfig> = {
    name: '',
    email: '',
    environment: 'personal',
    system: '',
    yubiKey: '',
  };

  for (const line of content.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;

    const eqIdx = trimmed.indexOf('=');
    if (eqIdx === -1) continue;

    const key = trimmed.slice(0, eqIdx);
    let value = trimmed.slice(eqIdx + 1);
    // Strip surrounding quotes
    value = value.replace(/^["']|["']$/g, '');

    switch (key) {
      case 'DOT_NAME':        config.name = value; break;
      case 'DOT_EMAIL':       config.email = value; break;
      case 'DOT_ENVIRONMENT': config.environment = value as 'work' | 'personal'; break;
      case 'DOT_SYSTEM':      config.system = value; break;
      case 'DOT_YUBIKEY':     config.yubiKey = value; break;
    }
  }

  return config as DotConfig;
}

export function saveConfig(dotfilesDir: string, config: DotConfig): void {
  const lines = [
    '# Dotfiles configuration',
    `DOT_NAME="${config.name}"`,
    `DOT_EMAIL="${config.email}"`,
    `DOT_ENVIRONMENT="${config.environment}"`,
    `DOT_SYSTEM="${config.system}"`,
  ];

  if (config.yubiKey) {
    lines.push(`DOT_YUBIKEY="${config.yubiKey}"`);
  }

  fs.writeFileSync(
    path.join(dotfilesDir, CONFIG_FILE),
    lines.join('\n') + '\n',
    'utf-8',
  );
}

export function configToEnv(config: DotConfig): Record<string, string> {
  const env: Record<string, string> = {
    DOT_NAME: config.name,
    DOT_EMAIL: config.email,
    DOT_ENVIRONMENT: config.environment,
    DOT_SYSTEM: config.system,
    DOT_YUBIKEY: config.yubiKey,
    DOT_SYMLINK_MODE: 'override',
  };

  if (config.environment === 'work') {
    env.WORK_ENV = '1';
  }

  return env;
}
