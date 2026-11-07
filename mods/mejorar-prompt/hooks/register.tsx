import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Original } from '../types'

const original = atom({ plugin: 'mejorar-prompt', key: 'original' } as const, null as Original)
const isBusy = atom({ plugin: 'mejorar-prompt', key: 'isBusy' } as const, false)

const SYSTEM = `Sos un editor de prompts para Claude Code (un agente de programación).
Reescribís el borrador del usuario para que el agente lo entienda a la primera.

Reglas:
- Respondé SOLO con el prompt reescrito, sin comillas, sin explicaciones, sin encabezados tipo "Prompt mejorado".
- Mismo idioma que el borrador (si está en español rioplatense, mantené el voseo).
- No inventes requisitos, archivos, tecnologías ni datos que el borrador no diga. Si falta algo importante, agregá al final una línea "Si no está claro: <pregunta>" en vez de suponer.
- Dejá claro: qué hay que hacer, sobre qué (archivos, proyecto, área), restricciones que el usuario mencionó, y cómo se sabe que está listo.
- Corregí ortografía y ordená ideas sueltas en pasos o viñetas cortas si son varias cosas.
- Mantené rutas, comandos, nombres y código exactamente como están.
- Si el borrador ya es claro y corto, devolvelo casi igual. No lo alargues por alargar.`


async function improve($: EngineInterface, given?: string): Promise<string> {
  if (await read($, isBusy)) return 'Ya se está mejorando el prompt.'
  const text = given && given.trim() !== '' ? given : (await $.prompt.read()).text
  const draft = text.trim()
  if (draft === '') {
    $.ui.toast('Escribí algo en el prompt primero')
    return 'El prompt está vacío.'
  }

  await update($, isBusy, () => true)
  $.ui.status('✨ Mejorando prompt…')
  try {
    const r = await $.model.complete({
      model: 'haiku',
      system: SYSTEM,
      prompt: `Borrador:\n<<<\n${text}\n>>>`,
      maxTokens: 2000,
      effort: 'low',
      timeoutMs: 45000,
    })
    if (!r.isAnswered || r.text.trim() === '') {
      $.ui.toast(`No se pudo mejorar (${r.isAnswered ? 'respuesta vacía' : r.reason})`)
      return 'No se pudo mejorar el prompt.'
    }
    await update($, original, () => text)
    const filled = await $.prompt.fill({ text: r.text.trim(), mode: 'replace' })
    if (!filled.isFilled) {
      $.ui.toast('No pude escribir en el cuadro del prompt')
      return 'No pude reemplazar el prompt.'
    }
    $.ui.toast('Prompt mejorado. Revisalo y envialo, o tocá Deshacer.')
    return 'Prompt mejorado en el cuadro.'
  } finally {
    await update($, isBusy, () => false)
    $.ui.status(undefined)
  }
}

async function undo($: EngineInterface): Promise<string> {
  const before = await read($, original)
  if (before === null) return 'No hay nada para deshacer.'
  await $.prompt.fill({ text: before, mode: 'replace' })
  await update($, original, () => null)
  return 'Prompt original restaurado.'
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'mejorar',
      description: 'Reescribe el borrador del prompt para que quede más claro (no lo envía)',
    })
    await $.command.register({
      name: 'mejorar-deshacer',
      description: 'Vuelve al prompt que tenías antes de /mejorar',
    })
    return next(e)
  })

  on('command.run', { command: 'mejorar' }, async ($, e) => ({ text: await improve($, e.args) }))
  on('command.run', { command: 'mejorar-deshacer' }, async $ => ({ text: await undo($) }))

  // Al enviar, se olvida el original: el Deshacer es solo para el borrador actual.
  on('prompt.submit', async ($, e, next) => {
    await update($, original, () => null)
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (e.props.hasSurvey) return next(e)
    // Otro plugin (p. ej. desktop-statusline) puede dibujar esta franja: se lo incluye arriba.
    const below = await next(e)
    const { Box, Button, Text } = $.ui.resolve(e)
    const busy = await read($, isBusy)
    const canUndo = (await read($, original)) !== null

    return (
      <Box flexDirection="column">
        {below ?? null}
        <Box>
        {busy ? (
          <Text dimColor>✨ Mejorando prompt…</Text>
        ) : (
          <Button key="mejorar" label="✨ Mejorar prompt" onPress={() => void improve($)} />
        )}
        {canUndo && !busy ? (
          <Button key="deshacer" label="↶ Deshacer" onPress={() => void undo($)} />
        ) : null}
        </Box>
      </Box>
    )
  })
}
