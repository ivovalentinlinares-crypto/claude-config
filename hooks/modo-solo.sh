#!/usr/bin/env bash
# Hook PreToolUse para AskUserQuestion: en vez de frenar esperando una respuesta,
# anota la pregunta en DUDAS.md (raíz del proyecto) y le dice a Claude que decida
# solo y siga. Para volver a recibir preguntas: touch ~/.claude/estoy-aca
# (borrarlo reactiva el modo solo).
set -euo pipefail

[[ -e "$HOME/.claude/estoy-aca" ]] && exit 0

entrada="$(cat)"
dir="${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // empty' <<<"$entrada")}"
dir="${dir:-$PWD}"
dudas="$dir/DUDAS.md"

[[ -f "$dudas" ]] || printf '# Dudas pendientes\n\nPreguntas que Claude tuvo mientras trabajaba solo. Cada una dice qué eligió.\n' >"$dudas"
{
  printf '\n## %s\n\n' "$(date '+%Y-%m-%d %H:%M')"
  jq -r '.tool_input.questions[]? |
    "**" + .question + "**\n" +
    ([.options[]? | "- " + .label + (if .description then ": " + .description else "" end)] | join("\n")) +
    "\n"' <<<"$entrada"
  printf -- '- **Elegido:** _(Claude lo completa abajo)_\n'
} >>"$dudas"

cat >&2 <<EOF
El usuario no está disponible (modo solo): la pregunta NO se le mostró y quedó anotada en $dudas.
No vuelvas a preguntar. Elegí vos: la opción recomendada, o si no hay, la más segura y reversible.
Reemplazá la línea "Elegido" de esa entrada en DUDAS.md por lo que elegiste y por qué (una línea), y seguí trabajando.
EOF
exit 2
