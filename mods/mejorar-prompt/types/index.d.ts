export type Original = string | null

declare module 'claude-code' {
  interface PluginState {
    'mejorar-prompt': { original: Original; isBusy: boolean }
  }
}
