export type Nivel = 'low' | 'medium' | 'high' | 'xhigh' | 'max'

declare module 'claude-code' {
  interface PluginState {
    'esfuerzo-auto': { nivel: Nivel | null; fijo: Nivel | null }
  }
}
