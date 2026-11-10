# claude-config

Mi configuración de Claude Code en un solo lugar: agentes, hooks, skills, mods, `CLAUDE.md` y los settings que administro. Está armada para gastar pocos tokens sin perder inteligencia, y cada regla importante la cumple un mecanismo (setting o hook), no la memoria del modelo. El porqué, con las mediciones, está en [DISEÑO.md](DISEÑO.md).

## Instalar

```bash
./install.sh --dry-run   # ver qué haría
./install.sh             # instalar
```

`install.sh` enlaza (symlink) cada agente, skill y hook dentro de `~/.claude`, así que **el repo es la fuente**: si editás algo acá, Claude Code lo ve en la próxima sesión. Lo que ya existía en `~/.claude` con el mismo nombre se mueve a `~/.claude/backups/claude-config-<fecha>/`. En `settings.json` solo mezcla las claves de `claude/settings.managed.json` (un `null` borra la clave) y registra los mods; el resto no lo toca.

## Qué hay

| Carpeta | Contenido |
|---|---|
| `claude/CLAUDE.example.md` | Plantilla de instrucciones globales: memoria en una carpeta de Markdown (p. ej. Obsidian), graphify, delegación y reglas de contexto, modo solo. La primera instalación la copia a `claude/CLAUDE.md`, que es tuyo y no se sube |
| `claude/settings.managed.json` | Modelo, ventana de compactación de 200k, plugins, skills que se listan sin descripción, modo auto y hooks |
| `agents/` | 7 agentes con modelo, razonamiento, tope de turnos y ventana de compactación propia |
| `hooks/` | Estado del repo al compactar o retomar, instrucciones para el resumen, protección de `main`, modo solo |
| `skills/` | 25 skills: 3 automáticos, el resto manuales (`/nombre`) |
| `mods/esfuerzo-auto/` | Elige solo el razonamiento de cada prompt (bajo, medio, alto, muy alto, max) con una clasificación rápida de haiku; `/esfuerzo <nivel>` lo fija y `/esfuerzo auto` lo devuelve a automático |
| `mods/mejorar-prompt/` | `/mejorar` reescribe el prompt con haiku antes de enviarlo; `/mejorar-deshacer` vuelve atrás |
| `scripts/medir-tokens.py` | Mide en qué se van los tokens leyendo los transcripts: `scripts/medir-tokens.py Consorcio --desde 2026-11-10` |

### Settings

| Clave | Valor | Por qué |
|---|---|---|
| `autoCompactWindow` | `200000` | Cada pedido reenvía toda la conversación; la mediana era 281k. Topear a 200k ahorra hasta un cuarto del total |
| `model` | `opus` | Opus en el hilo principal. `opusplan` cambiaba de modelo al salir del modo plan y eso rehace la caché entera |
| `CLAUDE_CODE_SUBAGENT_MODEL` | Sonnet 5.5 | Modelo de los subagentes sin modelo propio (general-purpose) |
| `enabledPlugins` | sin context-mode ni skill-creator | context-mode costaba más de lo que ahorraba; skill-creator ya viene en los skills de Anthropic |
| `skillOverrides` | `name-only` | Skills de documentos y de cuenta que no se usan programando: se listan sin descripción, siguen disponibles |
| Borrados | `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | El primero queda reemplazado por la ventana; el segundo no se usaba y suma herramientas |

### Agentes

Claude elige el agente solo, según cuánto hay que pensar. Todos tienen `maxTurns` (devuelven un resultado parcial que se puede retomar) y compactan a los 150k.

| Agente | Modelo | Razonamiento | Para qué |
|---|---|---|---|
| codigo-medio | Sonnet | medio | tarea común en 1 a 3 archivos, bug con causa clara, renombres, errores de compilación |
| codigo-dificil | Opus | alto | varios módulos, async, bug de causa desconocida |
| codigo-experto | Opus | muy alto | refactor grande, concurrencia, seguridad, migraciones, algo que ya falló |
| arquitecto | Opus | max | diseñar antes de programar (no edita) |
| rust-reviewer · network-troubleshooter (de ECC) | Sonnet | medio | revisar Rust · red |
| motion-reviewer | Sonnet | medio | auditar animaciones |

Para buscar código se usa el `Explore` de fábrica (no carga los `CLAUDE.md` y es barato). La compilación la verifica el hook `Stop` de cada proyecto.

### Hooks

| Hook | Evento | Qué hace |
|---|---|---|
| `estado-sesion.sh` | SessionStart | Al compactar o retomar: rama, cambios sin commitear, últimos commits, «Qué sigue» de `PROGRESO.md` y dudas abiertas. Al arrancar, solo avisa si hay dudas pendientes |
| `antes-de-compactar.sh` | PreCompact | Le dice al resumen qué conservar: pedidos, decisiones, archivos, errores, qué está verificado y qué sigue |
| `proteger-main.sh` | PreToolUse (Bash) | Frena `git commit` en `main`; `git push` a `main` y `gh pr merge` solo pasan si estás presente (`estoy-aca.sh si`) |
| `modo-solo.sh` | PreToolUse (AskUserQuestion) | Si no estás, la pregunta va a `DUDAS.md` y Claude sigue con la opción más segura |
| `estoy-aca.sh` | (a mano) | `estoy-aca.sh si` / `no` / `estado`: prende o apaga el modo solo |

### Skills

- **Automáticos** (Claude los elige): systematic-debugging, brainstorming, verification-before-completion. graphify y prowl también, pero los instalan sus propias herramientas y no están en este repo.
- **Manuales** (`disable-model-invocation: true`, no ocupan contexto hasta que los llamás): writing-plans, executing-plans, test-driven-development, emil-design-eng, apple-design, improve-animations, motion, playwright-cli y los `ecc-*`.

Para que un skill pase a manual o a automático, agregá o borrá `disable-model-invocation: true` en el encabezado de su `SKILL.md`.

## opencode

`install.sh` también instala el equivalente en opencode (v2) si está instalado; solo opencode: `./install-opencode.sh [--dry-run]`.

| Pieza de Claude Code | En opencode |
|---|---|
| `CLAUDE.md` | `opencode/AGENTS.md` (personal, no se sube; sale de `AGENTS.example.md`) enlazado en `~/.config/opencode/AGENTS.md` |
| `agents/*.md` y los agentes de plugins | se traducen a `~/.config/opencode/agents/` con el modelo de `opencode/modelos.json`; sin `Edit`/`Write` en `tools:` quedan de solo lectura. Editá el original y volvé a correr el instalador |
| Modelos | GLM 5.3 por Novita AI para todo; GLM 5.3 Flash para lectura (`explore`, títulos). El `effort` pasa a la variante: low→low, medium→sin variante, high→high, xhigh y max→max. `plan` usa `#high` |
| Skills | opencode lee `~/.claude/skills` solo y respeta `disable-model-invocation`; los skills de plugins activos se agregan en `skills`. Los de la app de Claude que no sirven fuera de ella (navegador, computer-use, Docs…) se bloquean en `opencode.base.json` |
| MCP de plugins activos | `mcp.servers` |
| Modo auto + hook de modo solo | permisos de fábrica (todo permitido) y `question: deny` en `build` y `plan` |
| Cerebro (Obsidian) | las mismas reglas en `AGENTS.md`; `Credenciales/` bloqueada y `Recursos/` pregunta por permisos |
| Compactación | `compaction.buffer: 20%` |

La API key de Novita no está en el repo: se guarda con `opencode auth login`. `mejorar-prompt` tiene su versión en `opencode/commands/`: `/mejorar <texto>` devuelve el prompt reescrito con GLM 5.3 Flash (agente oculto `mejorador`, sin herramientas) para que lo copies y lo mandes; `/mejorar-y-hacer <texto>` lo ordena y lo ejecuta en el mismo paso. opencode no deja reemplazar el texto del cuadro del prompt, así que no hay botón ni deshacer. `esfuerzo-auto` no tiene equivalente: la variante se cambia a mano desde el selector de modelo.

## Origen y licencias

- Skills de proceso (brainstorming, systematic-debugging, etc.): copiados de [superpowers](https://github.com/obra/superpowers) 7.0.0, MIT. Se quitó el hook que obligaba a usarlos.
- `ecc-*` y los agentes rust-* y network-troubleshooter: de [Everything Claude Code](https://github.com/affaan-m/everything-claude-code), commit `d2ef268`, MIT. Sin sus hooks, reglas ni instalador.
- Para traer más de ECC: `git clone --depth 1 https://github.com/affaan-m/everything-claude-code vendor/ecc` (está en `.gitignore`), copiar el skill a `skills/ecc-<nombre>/` y agregarle `disable-model-invocation: true`.

## Mods

El botón del mod no se ve en la app de escritorio porque el plugin `desktop-statusline` ocupa la franja sobre el cuadro del prompt. El comando funciona: `/mejorar <texto>`, o escribir el texto, borrarlo y mandar `/mejorar` solo.
