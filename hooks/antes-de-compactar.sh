#!/usr/bin/env bash
# Hook PreCompact. Lo que imprime son instrucciones para el resumen de la
# compactación (Claude Code usa el stdout; máximo 10.000 caracteres).
# Objetivo: compactar seguido (ventana de 200k) sin perder el hilo.
cat <<'EOF'
Al resumir esta conversación, conservá con precisión:
1. Los pedidos del usuario con sus palabras, sobre todo el último, y cada corrección que hizo.
2. Las decisiones tomadas y por qué, incluidas las opciones descartadas.
3. Cada archivo creado o modificado, con su ruta y qué cambió.
4. Los comandos que fallaron, con el error exacto, y cómo se resolvió (o si sigue abierto).
5. Qué está verificado (qué se corrió y qué dio) y qué no se probó.
6. Los pasos pendientes en orden y el siguiente paso concreto.
7. Ramas, PRs, worktrees, sesiones o procesos en marcha.
Descartá: salidas de herramientas que ya se usaron, contenido de archivos (se pueden releer), búsquedas que no llevaron a nada y explicaciones ya entregadas.
EOF
