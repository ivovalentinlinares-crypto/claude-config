#!/usr/bin/env bash
# Instala esta configuración en ~/.claude usando enlaces simbólicos:
# el repo queda como fuente única; editar acá cambia Claude Code al instante.
#   ./install.sh            instala
#   ./install.sh --dry-run  muestra qué haría, sin tocar nada
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE="${CLAUDE_HOME:-$HOME/.claude}"
DRY=0; [[ "${1:-}" == "--dry-run" ]] && DRY=1
BACKUP="$CLAUDE/backups/claude-config-$(date +%Y%m%d-%H%M%S)"

run() { if ((DRY)); then echo "  [seco] $*"; else "$@"; fi; }

# Enlaza $1 (en el repo) en $2 (en ~/.claude). Si ya hay algo que no es
# nuestro enlace, lo mueve al respaldo antes.
link() {
  local src="$1" dst="$2"
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then return; fi
  if [[ -e "$dst" || -L "$dst" ]]; then
    run mkdir -p "$BACKUP/$(dirname "${dst#$CLAUDE/}")"
    run mv "$dst" "$BACKUP/${dst#$CLAUDE/}"
    echo "  respaldo: ${dst#$CLAUDE/}"
  fi
  run ln -s "$src" "$dst"
  echo "  enlace:   ${dst#$CLAUDE/}"
}

echo "== CLAUDE.md"
# claude/CLAUDE.md es personal y no se sube (ver .gitignore); la primera vez sale del ejemplo.
if [[ ! -f "$REPO/claude/CLAUDE.md" ]]; then
  run cp "$REPO/claude/CLAUDE.example.md" "$REPO/claude/CLAUDE.md"
  echo "  creado claude/CLAUDE.md desde el ejemplo: editalo con tus rutas"
fi
link "$REPO/claude/CLAUDE.md" "$CLAUDE/CLAUDE.md"

echo "== agentes"
run mkdir -p "$CLAUDE/agents"
for f in "$REPO"/agents/*.md; do link "$f" "$CLAUDE/agents/$(basename "$f")"; done

echo "== skills"
run mkdir -p "$CLAUDE/skills"
for d in "$REPO"/skills/*/; do d="${d%/}"; link "$d" "$CLAUDE/skills/$(basename "$d")"; done

echo "== limpiar enlaces rotos al repo (agentes o skills renombrados o borrados)"
for l in "$CLAUDE"/agents/* "$CLAUDE"/skills/*; do
  if [[ -L "$l" && ! -e "$l" ]]; then
    case "$(readlink "$l")" in
      "$REPO"/*|*/claude-config/*) run rm "$l"; echo "  quitado:  ${l#$CLAUDE/}" ;;
    esac
  fi
done

echo "== settings.json (mezcla, no pisa lo que no administramos)"
SETTINGS="$CLAUDE/settings.json"
if ((DRY)); then
  echo "  [seco] mezclaría claude/settings.managed.json y CLAUDE_CODE_PLUGIN_DIRS con cada carpeta de mods/"
else
  mkdir -p "$BACKUP"; [[ -f "$SETTINGS" ]] && cp "$SETTINGS" "$BACKUP/settings.json"
  python3 - "$SETTINGS" "$REPO/claude/settings.managed.json" "$REPO/mods" <<'EOF'
import json, os, sys
path, managed_path, mods = sys.argv[1:]
cur = json.load(open(path)) if os.path.exists(path) else {}
managed = json.load(open(managed_path))
for k, v in managed.items():
    if isinstance(v, dict):
        cur.setdefault(k, {}).update(v)
    else:
        cur[k] = v
dirs = sorted(os.path.join(mods, d) for d in os.listdir(mods)
              if os.path.isfile(os.path.join(mods, d, ".claude-plugin", "plugin.json")))
cur.setdefault("env", {})["CLAUDE_CODE_PLUGIN_DIRS"] = os.pathsep.join(dirs)
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(cur, f, indent=2, ensure_ascii=False); f.write("\n")
os.replace(tmp, path)
print("  mods:", ", ".join(os.path.basename(d) for d in dirs))
EOF
fi

if command -v opencode >/dev/null && [[ -x "$REPO/install-opencode.sh" ]]; then
  echo; echo "== opencode"
  "$REPO/install-opencode.sh" "${1:-}"
fi

echo
((DRY)) && echo "Prueba en seco: no se tocó nada." || echo "Listo. Respaldo en: $BACKUP. Reiniciá Claude Code para que tome todo."
