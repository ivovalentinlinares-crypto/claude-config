#!/usr/bin/env bash
# Batería de pruebas de los hooks. No toca la configuración ni los repos: arma
# repos de prueba en una carpeta temporal y le pasa a cada hook la entrada JSON
# que le daría Claude Code.
#   scripts/probar-hooks.sh                       hooks globales
#   scripts/probar-hooks.sh <checkout de Consorcio>  también los del proyecto
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
H="$REPO/hooks"
PROY="${1:-}"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
ok=0; mal=0
espera() { # espera <rc esperado> <descripción> <rc obtenido>
  if [[ "$1" == "$3" ]]; then ok=$((ok + 1)); printf '  ✓ %s\n' "$2"
  else mal=$((mal + 1)); printf '  ✗ %s (esperaba %s, dio %s)\n' "$2" "$1" "$3"; fi
}
bashjson() { jq -n --arg c "$1" --arg d "$2" '{tool_input:{command:$c},cwd:$d}'; }

git -C "$T" init -q -b main main && git -C "$T/main" -c user.name=p -c user.email=p@p commit -q --allow-empty -m base
git -C "$T" init -q -b claude/x rama

echo "== proteger-main.sh"
p() { bashjson "$3" "$2" | HOME="$T" bash "$H/proteger-main.sh" >/dev/null 2>&1; espera "$1" "$3" $?; }
p 2 "$T/main" "git commit -m x"
p 2 "$T/main" "git -c user.name=p -c user.email=p@p commit -m x"
p 2 "/"       "cd $T/main && git commit -am x"
p 2 "/"       "git -C $T/main commit -m x"
p 2 "$T/main" "git push"
p 2 "$T/rama" "git push origin main"
p 2 "$T/rama" "git push origin HEAD:main"
p 2 "$T/rama" "git push origin +claude/x:refs/heads/main"
p 2 "$T/rama" "git push --all origin"
p 2 "$T/rama" "gh pr merge 3 --squash"
p 0 "$T/rama" "git commit -m x"
p 0 "$T/rama" "git push -u origin claude/x"
p 0 "$T/main" "git status && git log --oneline -3"
p 0 "$T/main" "git -c a=b status"
p 0 "$T/main" "ls | grep git"
p 0 "$T/main" "echo git push origin main > nota.txt"
mkdir -p "$T/.claude"; touch "$T/.claude/estoy-aca"   # usuario presente
p 2 "$T/main" "git commit -m x"
p 0 "$T/rama" "git push origin main"
p 0 "$T/rama" "gh pr merge 3"
rm "$T/.claude/estoy-aca"

echo "== estado-sesion.sh"
printf '# P\n## Qué sigue\nhacer A\n## Otra\nno\n' >"$T/rama/PROGRESO.md"
printf '# Dudas\n- **PENDIENTE: algo**\n' >"$T/rama/DUDAS.md"
s="$(jq -n '{source:"startup"}' | CLAUDE_PROJECT_DIR="$T/rama" bash "$H/estado-sesion.sh")"
espera 0 "al arrancar solo avisa las dudas" "$([[ "$s" == "DUDAS.md tiene 1 dudas sin resolver." ]] && echo 0 || echo 1)"
s="$(jq -n '{source:"compact"}' | CLAUDE_PROJECT_DIR="$T/rama" bash "$H/estado-sesion.sh")"
espera 0 "al compactar da rama, cambios y «Qué sigue»" "$([[ "$s" == *"Rama: claude/x"* && "$s" == *"PROGRESO.md"* && "$s" == *"hacer A"* && "$s" != *"no"$'\n'* ]] && echo 0 || echo 1)"
espera 0 "la salida es corta (<3000 caracteres)" "$(( ${#s} < 3000 ? 0 : 1 ))"
s="$(jq -n '{source:"resume"}' | CLAUDE_PROJECT_DIR="$T" bash "$H/estado-sesion.sh")"; espera 0 "fuera de un repo no falla" $?

echo "== antes-de-compactar.sh"
s="$(bash "$H/antes-de-compactar.sh")"
espera 0 "instrucciones para el resumen (<10000 caracteres)" "$([[ -n "$s" && ${#s} -lt 10000 ]] && echo 0 || echo 1)"

echo "== modo-solo.sh"
q='{"cwd":"'"$T/rama"'","tool_input":{"questions":[{"question":"¿A o B?","options":[{"label":"A"},{"label":"B"}]}]}}'
HOME="$T" CLAUDE_PROJECT_DIR="$T/rama" bash "$H/modo-solo.sh" <<<"$q" >/dev/null 2>&1; espera 2 "sin el usuario, frena la pregunta" $?
espera 0 "y la anota en DUDAS.md" "$(grep -q '¿A o B?' "$T/rama/DUDAS.md" && echo 0 || echo 1)"
touch "$T/.claude/estoy-aca"
HOME="$T" CLAUDE_PROJECT_DIR="$T/rama" bash "$H/modo-solo.sh" <<<"$q" >/dev/null 2>&1; espera 0 "con el usuario presente, deja preguntar" $?

if [[ -n "$PROY" ]]; then
  echo "== hooks del proyecto ($PROY)"
  m="$(ls "$PROY"/crates/datos/migrations/*.sql | tail -1)"
  jq -n --arg f "$m" '{tool_input:{file_path:$f}}' | bash "$PROY/.claude/hooks/migraciones.sh" 2>/dev/null; espera 2 "migraciones: frena una commiteada" $?
  jq -n --arg f "$PROY/crates/datos/migrations/29990101000000_x.sql" '{tool_input:{file_path:$f}}' | bash "$PROY/.claude/hooks/migraciones.sh"; espera 0 "migraciones: deja una nueva" $?
  jq -n --arg f "$PROY/crates/app/src/lib.rs" '{tool_input:{file_path:$f}}' | bash "$PROY/.claude/hooks/migraciones.sh"; espera 0 "migraciones: ignora otros archivos" $?
  if [[ -z "$(git -C "$PROY" status --porcelain -- '*.rs')" ]]; then
    jq -n '{session_id:"prueba"}' | CLAUDE_PROJECT_DIR="$PROY" bash "$PROY/.claude/hooks/verificar-al-terminar.sh" >/dev/null; espera 0 "Stop: sin cambios de Rust no hace nada" $?
  fi
  for f in "$PROY/.claude/settings.json"; do jq -e . "$f" >/dev/null; espera 0 "settings.json del proyecto es JSON válido" $?; done
fi

echo "== JSON"
jq -e . "$REPO/claude/settings.managed.json" >/dev/null; espera 0 "settings.managed.json válido" $?
jq -e '.autoCompactWindow == 200000 and .model == "opus"' ~/.claude/settings.json >/dev/null; espera 0 "settings.json instalado: ventana 200k y opus" $?
! grep -q 'context-mode' ~/.claude/settings.json; espera 0 "settings.json sin restos de context-mode (su servidor reescribía un hook)" $?

echo; echo "Resultado: $ok bien, $mal mal"
exit $((mal > 0))
