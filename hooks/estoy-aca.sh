#!/usr/bin/env bash
# Interruptor del modo solo de Claude Code.
#   estoy-aca.sh        cambia de estado (si estaba solo, pasa a preguntar, y al revés)
#   estoy-aca.sh si     estás en la PC: Claude te pregunta
#   estoy-aca.sh no     te vas: Claude anota las dudas en DUDAS.md y sigue solo
#   estoy-aca.sh estado muestra cómo está
# Toma efecto en la próxima pregunta, sin reiniciar la sesión.
f="$HOME/.claude/estoy-aca"
case "${1:-cambiar}" in
  si) touch "$f" ;;
  no) rm -f "$f" ;;
  estado) ;;
  *) if [[ -e "$f" ]]; then rm -f "$f"; else touch "$f"; fi ;;
esac
if [[ -e "$f" ]]; then
  echo "Estás acá: Claude te va a preguntar cuando tenga dudas."
else
  echo "Modo solo: Claude anota las dudas en DUDAS.md y sigue trabajando."
fi
