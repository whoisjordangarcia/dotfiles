import fs from 'fs';

export interface DetectedSystem {
  os: string;
  distro: string;
  system: string;
}

export function detectSystem(): DetectedSystem {
  if (process.platform === 'darwin') {
    return {os: 'mac', distro: '', system: 'mac'};
  }

  if (process.platform === 'linux') {
    const distro = detectLinuxDistro();
    return {os: 'linux', distro, system: `linux_${distro}`};
  }

  return {os: process.platform, distro: '', system: process.platform};
}

function detectLinuxDistro(): string {
  try {
    const content = fs.readFileSync('/etc/os-release', 'utf-8');
    for (const line of content.split('\n')) {
      const match = line.match(/^ID=["']?(\w+)["']?/);
      if (match) return match[1].toLowerCase();
    }
  } catch {
    // ignore read errors
  }
  return 'unknown';
}
