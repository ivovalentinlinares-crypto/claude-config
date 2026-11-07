# claude-config

Mi configuración de Claude Code en un solo lugar: skills, agentes, mods, `CLAUDE.md` y los settings que administro. Está pensada para gastar pocos tokens: casi todos los skills son **manuales** y cada agente tiene su modelo y su nivel de razonamiento.

## Instalar

```bash
./install.sh --dry-run   # ver qué haría
./install.sh             # instalar
```

`install.sh` enlaza (symlink) cada pieza dentro de `~/.claude`, así que **el repo es la fuente**: si editás un skill acá, Claude Code lo ve en la próxima sesión. Lo que ya existía en `~/.claude` con el mismo nombre se mueve a `~/.claude/backups/claude-config-<fecha>/`. En `settings.json` solo mezcla las claves de `claude/settings.managed.json` y registra los mods; el resto no lo toca.

## Qué hay

| Carpeta | Contenido |
|---|---|
| `claude/CLAUDE.example.md` | Plantilla de instrucciones globales: una carpeta de Markdown (p. ej. Obsidian) como única memoria, graphify, tabla de delegación a agentes. La primera instalación la copia a `claude/CLAUDE.md`, que es tuyo y no se sube |
| `claude/settings.managed.json` | Memoria nativa apagada, compactación automática al 80%, modelo de subagentes, plugins activos |
| `agents/` | 9 agentes con `model:` y `effort:` |
| `skills/` | 25 skills: 5 automáticos, el resto manuales (`/nombre`) |
| `mods/mejorar-prompt/` | `/mejorar` reescribe el prompt con haiku antes de enviarlo; `/mejorar-deshacer` vuelve atrás |
| `PLAN.md` | El plan y las decisiones del 2026-11-07 |

### Agentes

| Agente | Para qué | Modelo | Razonamiento |
|---|---|---|---|
| Explore | buscar y entender código | haiku | low |
| verificador | compilar, clippy, tests | haiku | low |
| liviano | cambios mecánicos | sonnet | low |
| rust-reviewer · rust-build-resolver · network-troubleshooter (de ECC) | Rust y red | sonnet | medium |
| motion-reviewer | auditar animaciones | sonnet | medium |
| experto | programar algo complejo | opus | high |
| arquitecto | diseño y bugs difíciles | opus | xhigh |

### Skills

- **Automáticos** (Claude los elige): systematic-debugging, brainstorming, verification-before-completion. graphify y prowl también, pero los instalan sus propias herramientas y no están en este repo.
- **Manuales** (`disable-model-invocation: true`, no ocupan contexto hasta que los llamás): writing-plans, executing-plans, test-driven-development, emil-design-eng, apple-design, improve-animations, motion, playwright-cli y los `ecc-*`.

Para que un skill pase a manual o a automático, agregá o borrá `disable-model-invocation: true` en el encabezado de su `SKILL.md`.

## Origen y licencias

- Skills de proceso (brainstorming, systematic-debugging, etc.): copiados de [superpowers](https://github.com/obra/superpowers) 7.0.0, MIT. Se quitó el hook que obligaba a usarlos.
- `ecc-*` y los agentes rust-* y network-troubleshooter: de [Everything Claude Code](https://github.com/affaan-m/everything-claude-code), commit `d2ef268`, MIT. Sin sus hooks, reglas ni instalador.
- Para traer más de ECC: `git clone --depth 1 https://github.com/affaan-m/everything-claude-code vendor/ecc` (está en `.gitignore`), copiar el skill a `skills/ecc-<nombre>/` y agregarle `disable-model-invocation: true`.

## Mods

El botón del mod no se ve en la app de escritorio porque el plugin `desktop-statusline` ocupa la franja sobre el cuadro del prompt. El comando funciona: `/mejorar <texto>`, o escribir el texto, borrarlo y mandar `/mejorar` solo.
