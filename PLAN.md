# Plan: ECC liviano + enrutado por agente + mod "mejorar prompt"

Fecha: 2026-11-07. ECC descargado en `ecc-revision/ecc` (commit d2ef268), sin ejecutar nada.

## Qué pesa en ECC (medido)

| Parte | Tamaño | Qué hacemos |
|---|---|---|
| Skills | 314 únicos (1068 archivos contando traducciones y espejos). Perfil `developer`: 133 skills, ~9,7k tokens solo de descripciones; `full`: ~24k | Quedarnos con ~15 |
| Reglas `rules/common` | 11 archivos siempre cargados, ~6k tokens | Resumir lo útil en ~1k dentro de CLAUDE.md |
| Hooks | Corren en **cada** llamada a herramienta. `observe` registra todo lo que hacés en `~/.local/share/ecc-homunculus`, `gateguard` frena la primera edición de cada archivo, `ecc-context-monitor` mete texto | No instalar ninguno |
| Agentes | 71, todos con modelo, ninguno con razonamiento, **no hay enrutador** | Tomar 3–4 (Rust) |
| Comandos | 98 | Tomar 3–5 |
| MCP | 34 en catálogo, inactivos | Ninguno |
| Telemetría | No tiene | — |

**No usamos `install.sh`**: corre scripts de Node y escribe hooks en `settings.json`. Copiamos a mano solo lo elegido.

## Fase 0 — Respaldo
- Copia de `~/.claude/settings.json`, `agents/`, `skills/` y `CLAUDE.md` en `~/.claude/backups/2026-11-07-ecc/`.
- Medir el contexto de una sesión vacía (`/context`) para comparar al final.

## Fase 1 — Limpiar lo que ya tenés
1. **Superpowers sin su hook.** El hook de superpowers obliga a usar skills ante "1% de chance". Desactivar el plugin y copiar a `~/.claude/skills/` solo: brainstorming, systematic-debugging, writing-plans, executing-plans, verification-before-completion, test-driven-development.
2. **Skills manuales.** A los skills que no querés que Claude use solo (Strix ×9, animación ×8, anatomy, reverse-engineer, y casi todos los de ECC) se les agrega `disable-model-invocation: true` en el encabezado de su `SKILL.md`. Así su descripción no entra al contexto y Claude nunca los llama: solo corren cuando escribís `/nombre`. Quedan automáticos solo los que convienen que Claude elija (graphify, prowl, systematic-debugging…).
   - Ojo: los skills que vienen de **plugins** (impeccable, context-mode, code-review) no se pueden editar, porque cada actualización pisa el cambio. Para esos, la opción es desactivar el plugin entero o dejarlo.
3. `CLAUDE_CODE_SUBAGENT_MODEL` de haiku a sonnet. Borrar `CLAUDE_FLOW_*`, `agents-disabled/` y versiones viejas de claude-mem en la caché.
4. **Memoria solo en Obsidian.**
   - `autoMemoryEnabled: false` en `settings.json`: apaga la memoria nativa (`MEMORY.md`), que hoy sigue activa aunque el `CLAUDE.md` diga que no se use.
   - Desinstalar claude-mem (está desactivado, pero instalado con 15 versiones).
   - De ECC no entra ningún skill ni hook de memoria (continuous-learning, sessions, save-session…).
   - context-mode guarda un índice de la sesión para buscar, pero se borra con la sesión: no es memoria de largo plazo. Si querés, se apaga también, aunque perdés su ahorro de contexto.
5. **Compactación automática solo cuando hace falta.** Claude Code ya compacta solo cuando el contexto se llena (`autoCompactEnabled`, encendido por defecto). Lo dejamos así y fijamos `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=80`: compacta al 80% en vez de esperar al borde, cuando las respuestas ya empiezan a empeorar. No instalamos el hook `suggest-compact` de ECC.

## Fase 2 — ECC selectivo
**Skills (copiar de `ecc/skills/`, prefijo `ecc-`):**
rust-patterns, rust-testing, mysql-patterns, database-migrations, docker-patterns, homelab-network-setup, homelab-vlan-segmentation, homelab-wireguard-vpn, network-config-validation, accessibility, seo, architecture-decision-records, hexagonal-architecture, safety-guard. Antes de copiar cada uno lo leo y recorto el relleno. Todos van como **manuales** (`/ecc-rust-patterns`, etc.), así que no suman nada al contexto hasta que los llamás. Como no cuestan, se pueden traer más de ECC si alguno te interesa.

**Descartados** (resumen): TDD/verificación/planes/orquestación (los cubre superpowers), memoria y aprendizaje continuo (Cerebro y graphify), motion y diseño (impeccable y tus skills de animación), búsqueda de código (graphify y prowl), lenguajes que no usás (Django, Spring, Kotlin, Swift, Go, C++, React, Vue…), dominios ajenos (logística, salud, cripto, marketing), los que piden API pagas (exa, fal, x-api, videodb).

**Agentes:** los de Rust (reviewer y build-resolver) y `network-troubleshooter`, adaptados a la tabla de la fase 3.
**Comandos:** `rust-build`, `rust-review`, `rust-test`.
**Reglas:** de `rules/common` extraer lo que no repita tu CLAUDE.md, en un bloque de ~1k caracteres.

## Fase 3 — Quién hace qué, con qué modelo y razonamiento
Sin agente enrutador: sería un salto extra con su propio costo en cada tarea. El hilo principal reparte con la tabla de tu `CLAUDE.md`, y cada agente trae su modelo y su `effort:` en el encabezado.

| Agente | Tarea | Modelo | Razonamiento |
|---|---|---|---|
| Explore | buscar y entender código | haiku | low |
| verificador | compilar, clippy, tests | haiku | low |
| liviano | cambios mecánicos | sonnet | low |
| rust-reviewer (ECC) | revisar Rust | sonnet | medium |
| rust-build-resolver (ECC) | arreglar errores de compilación | sonnet | medium |
| network-troubleshooter (ECC) | red, Proxmox, servers | sonnet | medium |
| motion-reviewer | auditar animaciones | sonnet | medium |
| experto | programar algo complejo | opus | high |
| arquitecto | diseño y bugs difíciles | opus | xhigh |

La tabla de delegación de `CLAUDE.md` se actualiza con las tres filas nuevas.

## Fase 4 — Mod "mejorar prompt"
- **Botón ✨ Mejorar** en una franja sobre el cuadro del prompt (solo aparece cuando escribiste algo), y además el comando `/mejorar`.
- Al apretarlo: lee lo que escribiste (`$.prompt.read`), se lo pasa a **haiku** con instrucciones basadas en el `prompt-optimizer` de ECC (aclarar objetivo, contexto, criterio de "listo", sin inventar requisitos, en tu idioma), y lo reemplaza en el cuadro (`$.prompt.fill`). **No lo envía**: lo revisás y mandás vos.
- Botón **Deshacer** para volver al texto original.
- Se escribe en `~/.claude/dev-mods/…/mejorar-prompt/`, con validación y tests (`claude plugin validate` / `claude plugin test`). El app te pregunta una vez si activás los mods.

## Fase 5 — Verificar
- Comparar `/context` de una sesión vacía contra la medición de la fase 0.
- Probar una tarea de cada tipo y ver que vaya al agente correcto.
- Nota en Cerebro (sesión y decisión) y agregarla al mapa.

## Para decidir
- ¿Usás **Laravel** o PHP puro? Si es Laravel, sumo `laravel-patterns` y `laravel-security`, recortados.
- ¿Usás **Vite**? Si sí, sumo `vite-patterns`.
- ¿Superpowers: desactivar el plugin y quedarte con las 6 copias (recomendado) o dejarlo como está?
- ¿Qué skills querés que Claude pueda usar solo, sin `/`? Propuesta: graphify, prowl, systematic-debugging, brainstorming y verification-before-completion. Todo lo demás, manual.
- ¿Apagar también context-mode?
