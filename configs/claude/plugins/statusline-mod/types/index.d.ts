/** Dev servers drawn above the prompt; `port` absent for an app of this checkout that isn't running. */
export type Apps = { name: string; port?: string }[]

declare module 'claude-code' {
  interface PluginState {
    'statusline-mod': { apps: Apps }
  }
}
