# Memoria: una sola nota índice (Obsidian u otra carpeta de Markdown)
<!-- Cambiá MEMORIA por la ruta de tu vault, por ejemplo ~/Documentos/Obsidian Vault/Memoria -->
La única memoria de largo plazo es `MEMORIA/`. No uses la memoria nativa (`MEMORY.md`) ni otros plugins de memoria: lo duradero va ahí, que el usuario también lee y edita.

- **Primero el índice.** Al empezar cualquier tarea leé `MEMORIA/Indice.md`: dice qué hay y qué leer. Después `MEMORIA/Preferencias.md`. Nada más hasta saber de qué trata la tarea.
- **Después, solo lo del tema.** Abrí únicamente las notas del índice que coinciden con la tarea. Nunca leas el vault entero; si algo no está en el índice, buscalo por nombre de archivo.
- **Nunca** abras carpetas de credenciales salvo que el usuario lo pida, ni copies claves, tokens o contraseñas a una nota.
- **Al terminar** algo que valga la pena, escribí una nota (una nota = un hecho) y agregala al índice con una línea: si no está en el índice, no se vuelve a encontrar.

# Grafo antes de leer (graphify, opcional)
Antes de explorar un proyecto, buscá `.graphify/graph.json` en su raíz. Si existe, consultalo primero (`graphify query "<pregunta>"`) y abrí solo los archivos que señale. Si no existe y el proyecto es grande (más de ~50 archivos de código), crealo con `/graphify <ruta>`. En proyectos chicos, leelos directo. Nunca incluyas `.env` ni claves en el grafo.

# Delegación a modelos baratos
- Buscar o entender código que requiere leer varios archivos: subagente `Explore`, no leerlos en el hilo principal.
- Compilar, clippy o correr tests: subagente `verificador`; nunca pegar la salida completa del compilador en la conversación.
- Cambios chicos y mecánicos con un patrón claro (renombres, texto, docs, agregar un campo): subagente `liviano`.
- Arquitectura, optimización profunda o bugs de causa desconocida: subagente `arquitecto` (Opus) antes de programar, o entrá en plan mode (con `opusplan` el plan corre en Opus).
- Programar algo complejo (varios archivos, concurrencia, rendimiento, algoritmos difíciles, refactors grandes, ejecutar el plan de `arquitecto`): subagente `experto` (Opus), que escribe el código y lo verifica.
- Revisar código Rust: subagente `rust-reviewer`. Errores de `cargo build` o del borrow checker: `rust-build-resolver`.
- Red, DNS, rutas o servers que no se ven: `network-troubleshooter` (solo lectura).
- El hilo principal queda para decidir y para programar lo no trivial. Elegí el agente sin preguntar.
- Los skills `ecc-*` y la mayoría de los demás son manuales (`/nombre`): no los busques ni los sugieras salvo que el usuario los nombre.
