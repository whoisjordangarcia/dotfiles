import chalk from 'chalk';

export const colors = {
  purple:    '#7C3AED',
  cyan:      '#06B6D4',
  green:     '#22C55E',
  red:       '#EF4444',
  yellow:    '#EAB308',
  blue:      '#3B82F6',
  muted:     '#6B7280',
  dim:       '#374151',
  white:     '#F9FAFB',
  highlight: '#1F2937',
};

export const t = {
  logo:       (s: string) => chalk.hex(colors.purple).bold(s),
  title:      (s: string) => chalk.hex(colors.cyan).bold(s),
  accent:     (s: string) => chalk.hex(colors.purple).bold(s),
  success:    (s: string) => chalk.hex(colors.green).bold(s),
  error:      (s: string) => chalk.hex(colors.red).bold(s),
  warning:    (s: string) => chalk.hex(colors.yellow)(s),
  muted:      (s: string) => chalk.hex(colors.muted)(s),
  selected:   (s: string) => chalk.hex(colors.green).bold(s),
  unselected: (s: string) => chalk.hex(colors.muted)(s),
  active:     (s: string) => chalk.white.bold(s),
  cursor:     (s: string) => chalk.hex(colors.cyan).bold(s),
  key:        (s: string) => chalk.hex(colors.purple).bold(s),
  sep:        (s: string) => chalk.hex(colors.dim)(s),
};

export function progressBar(current: number, total: number, width: number): string {
  const pct = total > 0 ? current / total : 0;
  const filled = Math.floor(width * pct);
  const empty = width - filled;
  return (
    chalk.hex(colors.green)('█'.repeat(filled)) +
    chalk.hex(colors.dim)('░'.repeat(empty))
  );
}

export const LOGO = `
  ░█████╗░████████╗░█████╗░██████╗░██╗░░░██╗███╗░░██╗
  ██╔══██╗╚══██╔══╝██╔══██╗██╔══██╗██║░░░██║████╗░██║
  ██║░░██║░░░██║░░░██║░░██║██████╦╝██║░░░██║██╔██╗██║
  ██║░░██║░░░██║░░░██║░░██║██╔══██╗██║░░░██║██║╚████║
  ╚█████╔╝░░░██║░░░╚█████╔╝██████╦╝╚██████╔╝██║░╚███║
  ░╚════╝░░░░╚═╝░░░░╚════╝░╚═════╝░░╚═════╝░╚═╝░░╚══╝`.trimStart();
