#!/usr/bin/env bash
# Hook PreToolUse para Bash. Frena lo que no se deshace solo:
#   - git commit sobre main o master (siempre: se trabaja en una rama);
#   - git push a main o master, git push --all/--mirror y gh pr merge,
#     salvo que el usuario esté presente (~/.claude/estoy-aca, ver estoy-aca.sh).
# Sale con 2 y explica por qué; Claude ve el mensaje y sigue por otro camino.
set -uo pipefail

entrada="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$entrada" 2>/dev/null)"
[[ "$cmd" == *git* || "$cmd" == *gh\ * ]] || exit 0
dir="$(jq -r '.cwd // empty' <<<"$entrada" 2>/dev/null)"
dir="${dir:-$PWD}"
presente=0; [[ -e "$HOME/.claude/estoy-aca" ]] && presente=1

frenar() {
  echo "Bloqueado por el hook proteger-main: $1" >&2
  echo "Trabajá en una rama (git switch -c claude/<tema>) y abrí un PR; unir a main lo decide el usuario. Si es imprescindible, anotalo en DUDAS.md como pendiente." >&2
  exit 2
}
rama_en() { git -C "$1" branch --show-current 2>/dev/null; }
es_main() { [[ "$1" == "main" || "$1" == "master" ]]; }

# Separa el comando en partes (&&, ||, ;, |, saltos de línea) y sigue los cd.
while IFS= read -r parte; do
  read -r -a pal <<<"$parte" || continue
  ((${#pal[@]})) || continue
  # Saltear asignaciones de variables al principio (FOO=1 git …).
  i=0; while [[ $i -lt ${#pal[@]} && "${pal[$i]}" == *=* && "${pal[$i]}" != -* ]]; do ((i++)); done
  p0="${pal[$i]:-}"
  if [[ "$p0" == "cd" ]]; then
    destino="${pal[$((i+1))]:-$HOME}"; destino="${destino/#\~/$HOME}"; destino="${destino//\"/}"; destino="${destino//\'/}"
    [[ "$destino" == /* ]] && dir="$destino" || dir="$dir/$destino"
    continue
  fi
  if [[ "$p0" == "gh" && "${pal[$((i+1))]:-}" == "pr" && "${pal[$((i+2))]:-}" == "merge" ]]; then
    ((presente)) || frenar "gh pr merge une a main y el usuario no está presente."
    continue
  fi
  [[ "$p0" == "git" ]] || continue
  gdir="$dir"; j=$((i+1))
  while [[ $j -lt ${#pal[@]} && "${pal[$j]}" == -* ]]; do
    if [[ "${pal[$j]}" == "-C" ]]; then g="${pal[$((j+1))]:-}"; g="${g/#\~/$HOME}"; g="${g//\"/}"; [[ "$g" == /* ]] && gdir="$g" || gdir="$dir/$g"; ((j++)); fi
    ((j++))
  done
  sub="${pal[$j]:-}"; resto=("${pal[@]:$((j+1))}")
  case "$sub" in
    commit)
      es_main "$(rama_en "$gdir")" && frenar "git commit sobre $(rama_en "$gdir")." ;;
    push)
      ((presente)) && continue
      refs=(); for a in "${resto[@]}"; do [[ "$a" == -* ]] || refs+=("$a"); done
      for a in "${resto[@]}"; do [[ "$a" == "--all" || "$a" == "--mirror" ]] && frenar "git push $a incluye main."; done
      if ((${#refs[@]} <= 1)); then
        es_main "$(rama_en "$gdir")" && frenar "git push desde $(rama_en "$gdir") sube a main."
      else
        for r in "${refs[@]:1}"; do
          destino="${r##*:}"; destino="${destino#+}"; destino="${destino#refs/heads/}"
          [[ "$destino" == "HEAD" ]] && destino="$(rama_en "$gdir")"
          es_main "$destino" && frenar "git push a $destino."
        done
      fi ;;
  esac
done < <(sed -E 's/(\&\&|\|\||;|\|)/\n/g' <<<"$cmd")
exit 0
