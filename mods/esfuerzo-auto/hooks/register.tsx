import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Nivel } from '../types'

// Nivel elegido para el prompt en curso, y nivel fijado a mano con /esfuerzo.
const nivel = atom({ plugin: 'esfuerzo-auto', key: 'nivel' } as const, null as Nivel | null)
const fijo = atom({ plugin: 'esfuerzo-auto', key: 'fijo' } as const, null as Nivel | null)

const NOMBRE: Record<Nivel, string> = {
  low: 'bajo',
  medium: 'medio',
  high: 'alto',
  xhigh: 'muy alto',
  max: 'max',
}
const POR_NOMBRE: Record<string, Nivel> = {
  bajo: 'low',
  medio: 'medium',
  alto: 'high',
  'muy-alto': 'xhigh',
  muyalto: 'xhigh',
  max: 'max',
}

const SYSTEM = `Clasificás pedidos que un usuario le hace a un agente de programación (Claude Code) según cuánto hay que pensar para resolverlos bien. Respondé SOLO una palabra: bajo, medio, alto, muy-alto o max.

- bajo: pregunta corta o de hecho, saludo, confirmación, cambio de texto, renombre, comando simple, leer o explicar algo puntual.
- medio: tarea común de programación en 1 a 3 archivos, bug con causa clara, agregar un campo o una función siguiendo un patrón, configurar algo conocido.
- alto: funcionalidad nueva en varios archivos, bug de causa desconocida, refactor de un módulo, integrar una librería, diseño de base de datos chico.
- muy-alto: arquitectura de un sistema o app completa, concurrencia, rendimiento, seguridad, migraciones de datos, refactor grande entre módulos, depurar algo que ya se intentó y falló.
- max: problemas excepcionalmente difíciles: algoritmos complejos, pruebas de correctitud, sistemas distribuidos, diseño crítico donde un error es muy caro.

Ante la duda entre dos niveles, elegí el más bajo.`

async function clasificar($: EngineInterface, texto: string): Promise<Nivel> {
  const r = await $.model.complete({
    model: 'haiku',
    system: SYSTEM,
    prompt: `Pedido:\n<<<\n${texto.slice(0, 6000)}\n>>>`,
    maxTokens: 10,
    effort: 'low',
    timeoutMs: 8000,
  })
  if (!r.isAnswered) return 'medium'
  const palabra = r.text.trim().toLowerCase().replace(/[^a-z-]/g, '')
  return POR_NOMBRE[palabra] ?? 'medium'
}

function mostrar($: EngineInterface, n: Nivel, manual: boolean) {
  $.ui.status(`🧠 ${NOMBRE[n]}${manual ? ' (fijo)' : ''}`)
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'esfuerzo',
      description: 'Fija el nivel de razonamiento (bajo, medio, alto, muy-alto, max) o vuelve a automático (auto)',
      argumentHint: 'bajo | medio | alto | muy-alto | max | auto',
    })
    const f = await read($, fijo)
    if (f) mostrar($, f, true)
    return next(e)
  })

  on('command.run', { command: 'esfuerzo' }, async ($, e) => {
    const arg = e.args.trim().toLowerCase()
    if (arg === '' || arg === 'auto') {
      await update($, fijo, () => null)
      $.ui.status('🧠 auto')
      return { text: 'Razonamiento automático: se elige según cada prompt.' }
    }
    const n = POR_NOMBRE[arg]
    if (!n) return { text: 'Usá: /esfuerzo bajo | medio | alto | muy-alto | max | auto' }
    await update($, fijo, () => n)
    mostrar($, n, true)
    return { text: `Razonamiento fijo en ${NOMBRE[n]} hasta que escribas /esfuerzo auto.` }
  })

  on('prompt.submit', async ($, e, next) => {
    // Comandos y mensajes internos no se clasifican.
    if (e.command || e.isMeta) return next(e)
    const manual = await read($, fijo)
    if (manual) {
      await update($, nivel, () => manual)
      mostrar($, manual, true)
      return next(e)
    }
    const anterior = await read($, nivel)
    const texto = e.text.trim()
    // Respuestas cortas ("sí", "dale, aplicalo") siguen la tarea anterior: mismo nivel.
    let n: Nivel
    if (anterior && texto.length < 30 && !texto.includes('\n')) {
      n = anterior
    } else {
      n = await clasificar($, texto)
    }
    await update($, nivel, () => n)
    mostrar($, n, false)
    return next(e)
  })

  // Aplica el nivel a cada pedido del hilo principal. Los subagentes usan el suyo.
  on('turn.step', async function* ($, e, next) {
    if (e.agentId !== undefined || e.effort === undefined) return yield* next(e)
    const n = await read($, nivel)
    if (!n || n === e.effort) return yield* next(e)
    return yield* next({ ...e, effort: n })
  })
}
