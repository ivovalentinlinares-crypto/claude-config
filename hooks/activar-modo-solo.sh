#!/usr/bin/env bash
# Activa el "modo solo" de Claude Code. Corrélo vos una vez (Claude no puede
# cambiar sus propios permisos). Hace un respaldo de settings.json antes.
#   1. permissions.defaultMode = "auto": trabaja sin pedir permiso en lo seguro y
#      rechaza solo lo riesgoso (en vez de quedarse esperándote).
#   2. Hook PreToolUse sobre AskUserQuestion: las preguntas van a DUDAS.md.
#   3. Lo mismo en claude/settings.managed.json, para que install.sh lo conserve.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS="$HOME/.claude/settings.json"

cp "$SETTINGS" "$SETTINGS.antes-modo-solo.bak"
mkdir -p "$HOME/.claude/hooks"
ln -sfn "$REPO/hooks/modo-solo.sh" "$HOME/.claude/hooks/modo-solo.sh"

for f in "$SETTINGS" "$REPO/claude/settings.managed.json"; do
  jq '.permissions.defaultMode = "auto"
      | .hooks.PreToolUse = [{matcher: "AskUserQuestion",
          hooks: [{type: "command", command: "~/.claude/hooks/modo-solo.sh"}]}]' \
    "$f" >"$f.tmp" && mv "$f.tmp" "$f"
done

MD="$REPO/claude/CLAUDE.md"
if ! grep -q '^# Modo solo' "$MD"; then
  cat >>"$MD" <<'EOF'

# Modo solo (trabajar sin el usuario)
El usuario muchas veces no está mirando. No frenes para preguntar:
- Ante una duda, elegí la opción recomendada o la más segura y reversible, anotala en `DUDAS.md` en la raíz del proyecto (pregunta, qué elegiste, por qué) y seguí.
- Si una acción queda bloqueada por permisos, anotala en `DUDAS.md` como pendiente y seguí con lo que no depende de ella.
- Lo irreversible o hacia afuera (push a main, borrar datos, mandar mensajes, gastar plata) no lo hagas: dejalo listo y anotado en `DUDAS.md`.
- Al terminar, el resumen final empieza por cuántas dudas quedaron en `DUDAS.md`.
EOF
fi

echo "Listo. Respaldo: $SETTINGS.antes-modo-solo.bak"
echo "Abrí una sesión nueva para que tome los cambios."
echo "Para volver a recibir preguntas: touch ~/.claude/estoy-aca  (borralo para reactivar el modo solo)"
