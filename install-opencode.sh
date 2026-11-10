#!/usr/bin/env bash
# Instala el equivalente de esta configuración en opencode (v2):
#   - opencode/AGENTS.md            -> ~/.config/opencode/AGENTS.md (enlace)
#   - agents/*.md (y los de plugins) -> ~/.config/opencode/agents/*.md, traducidos
#                                      con el modelo y la variante de opencode/modelos.json
#   - opencode/opencode.base.json + skills y MCP de los plugins activos
#                                    -> ~/.config/opencode/opencode.json (mezcla)
# Los skills de ~/.claude/skills los lee opencode solo (compatibilidad con Claude Code).
#   ./install-opencode.sh            instala
#   ./install-opencode.sh --dry-run  muestra qué haría, sin tocar nada
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OC="${OPENCODE_CONFIG_HOME:-$HOME/.config/opencode}"
CLAUDE="${CLAUDE_HOME:-$HOME/.claude}"
DRY=0; [[ "${1:-}" == "--dry-run" ]] && DRY=1
BACKUP="$OC/backups/claude-config-$(date +%Y%m%d-%H%M%S)"

run() { if ((DRY)); then echo "  [seco] $*"; else "$@"; fi; }

echo "== AGENTS.md (instrucciones globales)"
# opencode/AGENTS.md es personal y no se sube (ver .gitignore); la primera vez sale del ejemplo.
if [[ ! -f "$REPO/opencode/AGENTS.md" ]]; then
  run cp "$REPO/opencode/AGENTS.example.md" "$REPO/opencode/AGENTS.md"
  echo "  creado opencode/AGENTS.md desde el ejemplo: editalo con tus rutas"
fi
run mkdir -p "$OC"
dst="$OC/AGENTS.md"
if ! [[ -L "$dst" && "$(readlink "$dst")" == "$REPO/opencode/AGENTS.md" ]]; then
  if [[ -e "$dst" || -L "$dst" ]]; then run mkdir -p "$BACKUP"; run mv "$dst" "$BACKUP/AGENTS.md"; echo "  respaldo: AGENTS.md"; fi
  run ln -s "$REPO/opencode/AGENTS.md" "$dst"
  echo "  enlace:   AGENTS.md"
fi

echo "== comandos y agentes propios de opencode (enlaces)"
for sub in commands agents; do
  run mkdir -p "$OC/$sub"
  for f in "$REPO/opencode/$sub"/*.md; do
    [[ -e "$f" ]] || continue
    d="$OC/$sub/$(basename "$f")"
    [[ -L "$d" && "$(readlink "$d")" == "$f" ]] && continue
    if [[ -e "$d" || -L "$d" ]]; then run mkdir -p "$BACKUP/$sub"; run mv "$d" "$BACKUP/$sub/"; echo "  respaldo: $sub/$(basename "$f")"; fi
    run ln -s "$f" "$d"; echo "  enlace:   $sub/$(basename "$f")"
  done
done
for l in "$OC"/commands/* "$OC"/agents/*; do
  if [[ -L "$l" && ! -e "$l" && "$(readlink "$l")" == "$REPO"/* ]]; then run rm "$l"; echo "  quitado:  ${l#$OC/}"; fi
done

echo "== agentes y opencode.json"
python3 - "$REPO" "$OC" "$CLAUDE" "$BACKUP" "$DRY" <<'EOF'
import json, os, re, shutil, sys, glob

repo, oc, claude, backup, dry = sys.argv[1:]
dry = dry == "1"
MARCA = "# generado por claude-config/install-opencode.sh"
mapa = json.load(open(os.path.join(repo, "opencode", "modelos.json")))

def frontmatter(texto):
    """Devuelve (campos, cuerpo) de un .md con encabezado YAML simple."""
    m = re.match(r"^---\n(.*?)\n---\n?(.*)$", texto, re.S)
    if not m:
        return {}, texto
    campos, clave = {}, None
    for linea in m.group(1).splitlines():
        if clave and (linea.startswith("  ") or not linea.strip()):
            campos[clave] += (" " if campos[clave] else "") + linea.strip()
            continue
        k, _, v = linea.partition(":")
        clave = None
        if not _:
            continue
        k, v = k.strip(), v.strip()
        if v in ("|", ">", "|-", ">-"):
            campos[k], clave = "", k
        else:
            campos[k] = v.strip("\"'")
    return campos, m.group(2)

def modelo(campos):
    base = mapa["modelos"].get(campos.get("model", "").lower())
    if not base:
        return None  # inherit o desconocido: usa el modelo de la sesión
    var = mapa["variantes"].get(campos.get("effort", "").lower(), "")
    return f"{base}#{var}" if var else base

def traducir(origen, generados):
    campos, cuerpo = frontmatter(open(origen).read())
    nombre = campos.get("name") or os.path.splitext(os.path.basename(origen))[0]
    ident = nombre.split(":")[-1].lower()  # Explore -> explore (pisa el explore de fábrica)
    herramientas = {h.strip().lower() for h in campos.get("tools", "").split(",") if h.strip()}
    reglas = []
    if herramientas and not ({"edit", "write", "multiedit"} & herramientas):
        reglas.append(("edit", "deny"))
    if herramientas and "bash" not in herramientas:
        reglas.append(("shell", "deny"))
    lineas = ["---", MARCA + f" desde {os.path.relpath(origen, repo) if origen.startswith(repo) else origen}: editá el original",
              "description: " + json.dumps(campos.get("description", nombre), ensure_ascii=False),
              "mode: subagent"]
    mod = modelo(campos)
    if mod:
        lineas.append(f"model: {mod}")
    if reglas:
        lineas.append("permissions:")
        for accion, efecto in reglas:
            lineas += [f"  - action: {accion}", '    resource: "*"', f"    effect: {efecto}"]
    lineas.append("---")
    salida = "\n".join(lineas) + "\n" + cuerpo.lstrip("\n")
    dst = os.path.join(oc, "agents", ident + ".md")
    generados.add(dst)
    actual = open(dst).read() if os.path.exists(dst) else None
    if actual == salida:
        return
    if actual is not None and MARCA not in actual:
        print(f"  respaldo: agents/{ident}.md (no era nuestro)")
        if not dry:
            os.makedirs(os.path.join(backup, "agents"), exist_ok=True)
            shutil.move(dst, os.path.join(backup, "agents", ident + ".md"))
    print(f"  agente:   {ident:24} {mod or '(modelo de la sesión)'}" + ("  solo lectura" if ("edit", "deny") in reglas else ""))
    if not dry:
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, "w") as f:
            f.write(salida)

# Plugins activos de Claude Code (los que administra el repo) y dónde están instalados.
managed = json.load(open(os.path.join(repo, "claude", "settings.managed.json")))
activos = [p for p, on in managed.get("enabledPlugins", {}).items() if on]
instalados = {}
try:
    instalados = json.load(open(os.path.join(claude, "plugins", "installed_plugins.json"))).get("plugins", {})
except FileNotFoundError:
    pass
def ruta_plugin(pid):
    rutas = [i.get("installPath") for i in instalados.get(pid, []) if i.get("installPath") and os.path.isdir(i["installPath"])]
    return max(rutas, key=os.path.getmtime) if rutas else None

generados = set()
for f in sorted(glob.glob(os.path.join(repo, "agents", "*.md"))):
    traducir(f, generados)

skills, con_skills, servidores = [], [], {}
for pid in activos:
    raiz = ruta_plugin(pid)
    if not raiz:
        continue
    for f in sorted(glob.glob(os.path.join(raiz, "agents", "*.md"))):
        traducir(f, generados)
    if os.path.isdir(os.path.join(raiz, "skills")):
        skills.append(os.path.join(raiz, "skills")); con_skills.append(pid.split("@")[0])
    mcp = {}
    for cand in (os.path.join(raiz, ".mcp.json"), os.path.join(raiz, ".claude-plugin", "plugin.json")):
        if os.path.isfile(cand):
            d = json.load(open(cand))
            mcp.update(d.get("mcpServers", {}) if "mcpServers" in d or cand.endswith("plugin.json") else d)
    for nombre, s in mcp.items():
        if not isinstance(s, dict) or "command" not in s:
            continue
        sub = lambda x: x.replace("${CLAUDE_PLUGIN_ROOT}", raiz)
        srv = {"type": "local", "command": [sub(s["command"])] + [sub(a) for a in s.get("args", [])]}
        if s.get("env"):
            srv["environment"] = {k: sub(v) for k, v in s["env"].items()}
        servidores[nombre] = srv

# Borrar agentes generados antes que ya no existen en el repo.
for f in glob.glob(os.path.join(oc, "agents", "*.md")):
    if f not in generados and not os.path.islink(f) and MARCA in open(f).read():
        print(f"  quitado:  agents/{os.path.basename(f)}")
        if not dry:
            os.remove(f)

# opencode.json: mezcla la base del repo con lo que ya hubiera (no pisa claves ajenas).
path = os.path.join(oc, "opencode.json")
cur = json.load(open(path)) if os.path.exists(path) else {}
base = json.load(open(os.path.join(repo, "opencode", "opencode.base.json")))
for k, v in base.items():
    if k == "agents":
        for a, cfg in v.items():
            cur.setdefault("agents", {}).setdefault(a, {}).update(cfg)
    elif isinstance(v, dict) and isinstance(cur.get(k), dict):
        cur[k].update(v)
    else:
        cur[k] = v
if skills:
    cur["skills"] = skills
if servidores:
    cur.setdefault("mcp", {}).setdefault("servers", {}).update(servidores)
# Sacar los MCP de plugins que el repo apagó (por ejemplo context-mode).
for pid, on in managed.get("enabledPlugins", {}).items():
    raiz = ruta_plugin(pid) if not on else None
    if not raiz:
        continue
    for cand in (os.path.join(raiz, ".mcp.json"), os.path.join(raiz, ".claude-plugin", "plugin.json")):
        if os.path.isfile(cand):
            d = json.load(open(cand))
            for nombre in (d.get("mcpServers", {}) if "mcpServers" in d or cand.endswith("plugin.json") else d):
                if nombre not in servidores and cur.get("mcp", {}).get("servers", {}).pop(nombre, None) is not None:
                    print(f"  MCP quitado: {nombre} (plugin apagado)")
print("  skills de plugins:", ", ".join(con_skills) or "ninguno")
print("  MCP:", ", ".join(servidores) or "ninguno")
if dry:
    print("  [seco] escribiría", path)
else:
    if os.path.exists(path):
        os.makedirs(backup, exist_ok=True)
        shutil.copy2(path, os.path.join(backup, "opencode.json"))
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(cur, f, indent=2, ensure_ascii=False); f.write("\n")
    os.replace(tmp, path)
EOF

echo
if ((DRY)); then echo "Prueba en seco: no se tocó nada."
else echo "Listo. Reiniciá opencode (opencode service restart) para que tome todo."; fi
