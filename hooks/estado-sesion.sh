#!/usr/bin/env bash
# Hook SessionStart. Al compactar o retomar una sesión, el estado del repo que
# el modelo recuerda queda viejo: este hook le vuelve a dar rama, cambios sin
# commitear, últimos commits, "Qué sigue" de PROGRESO.md y las dudas abiertas.
# Al arrancar una sesión nueva la app ya trae el estado de git, así que solo
# avisa si hay dudas pendientes. Lo que imprime entra al contexto: va corto.
set -uo pipefail

entrada="$(cat)"
origen="$(jq -r '.source // "startup"' <<<"$entrada" 2>/dev/null)"
dir="${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // empty' <<<"$entrada" 2>/dev/null)}"
dir="${dir:-$PWD}"
cd "$dir" 2>/dev/null || exit 0

# Dudas que Claude todavía no resolvió (entradas sin completar o marcadas PENDIENTE).
pendientes=0
if [[ -f DUDAS.md ]]; then
  pendientes=$(grep -c -E '_\(Claude lo completa abajo\)_|\*\*PENDIENTE' DUDAS.md || true)
fi

if [[ "$origen" == "startup" || "$origen" == "fork" ]]; then
  ((pendientes > 0)) && echo "DUDAS.md tiene $pendientes dudas sin resolver."
  exit 0
fi

echo "Estado actual del proyecto (la sesión se $([[ $origen == compact ]] && echo compactó || echo retomó); lo que recuerdes de antes puede estar viejo):"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "- Rama: $(git branch --show-current 2>/dev/null || echo '(sin rama)')"
  cambios="$(git status --short 2>/dev/null)"
  if [[ -n "$cambios" ]]; then
    n=$(wc -l <<<"$cambios")
    echo "- Cambios sin commitear ($n):"
    head -15 <<<"$cambios" | sed 's/^/    /'
    ((n > 15)) && echo "    … y $((n - 15)) más"
  else
    echo "- Sin cambios sin commitear."
  fi
  echo "- Últimos commits:"
  git log --oneline -3 2>/dev/null | sed 's/^/    /'
fi

if [[ -f PROGRESO.md ]]; then
  sigue="$(awk 'BEGIN{IGNORECASE=1}
    /^#+ / { if (en) exit; if ($0 ~ /(qu[eé] sigue|pr[oó]xim|siguiente)/) { en=1; next } }
    en' PROGRESO.md | sed "/^[[:space:]]*$/d" | head -8)"
  [[ -n "$sigue" ]] && { echo "- PROGRESO.md, «Qué sigue»:"; sed 's/^/    /' <<<"$sigue"; }
fi
((pendientes > 0)) && echo "- DUDAS.md: $pendientes dudas sin resolver."
echo "Antes de editar un archivo, releelo: no confíes en fragmentos del resumen."
exit 0
