# Memoria: una sola nota índice (Obsidian u otra carpeta de Markdown)
<!-- Cambiá MEMORIA por la ruta de tu vault, por ejemplo ~/Documentos/Obsidian Vault/Memoria -->
La única memoria de largo plazo es `MEMORIA/`. No uses la memoria nativa (`MEMORY.md`) ni otros plugins de memoria: lo duradero va ahí, que el usuario también lee y edita.

- **Solo si la tarea lo necesita.** Leé `MEMORIA/Indice.md` cuando la tarea toque un proyecto, un tema o una decisión anterior que podría estar anotada, cuando el usuario mencione algo de antes o cuando vayas a escribir una nota. Para preguntas sueltas o cambios chicos, no lo abras. `MEMORIA/Preferencias.md` solo si la tarea depende de cómo le gusta trabajar al usuario.
- **Después, solo lo del tema.** Abrí únicamente las notas del índice que coinciden con la tarea. Nunca leas el vault entero; si algo no está en el índice, buscalo por nombre de archivo.
- **Nunca** abras carpetas de credenciales salvo que el usuario lo pida, ni copies claves, tokens o contraseñas a una nota.
- **Al terminar** algo que valga la pena, escribí una nota (una nota = un hecho) y agregala al índice con una línea: si no está en el índice, no se vuelve a encontrar.

# Grafo antes de leer (graphify, opcional)
Antes de explorar un proyecto, buscá `.graphify/graph.json` en su raíz. Si existe, consultalo primero (`graphify query "<pregunta>"`) y abrí solo los archivos que señale. Si no existe y el proyecto es grande (más de ~50 archivos de código), crealo con `/graphify <ruta>`. En proyectos chicos, leelos directo. Nunca incluyas `.env` ni claves en el grafo.

# Delegación por dificultad
Elegí el agente sin preguntar, según cuánto hay que pensar:

| Nivel | Agente | Modelo | Razonamiento | Cuándo |
|---|---|---|---|---|
| 1 | `codigo-facil` | Sonnet | bajo | renombres, textos, agregar un campo, un error de compilación obvio |
| 2 | `codigo-medio` | Sonnet | medio | tarea común en 1 a 3 archivos, bug con causa clara, tests |
| 3 | `codigo-dificil` | Opus | alto | varios módulos, async, bug de causa desconocida, ejecutar el plan de `arquitecto` |
| 4 | `codigo-experto` | Opus | muy alto | refactor grande, concurrencia, rendimiento, seguridad, migraciones, algo que ya falló |
| 5 | `arquitecto` | Opus | max | diseñar antes de programar algo grande o crítico (no edita) |

- Lo que se resuelve en pocos pasos (una edición, leer 1 o 2 archivos, un comando) hacelo directo: un subagente tarda en arrancar.
- Buscar o entender código en más de ~5 archivos: `Explore`. Compilar, clippy o tests largos: `verificador`; nunca pegues la salida completa.
- Rust: revisar con `rust-reviewer`; errores de `cargo build` o del borrow checker con `rust-build-resolver`.
- Red, DNS, rutas o servers que no se ven: `network-troubleshooter` (solo lectura).
- El razonamiento del hilo principal lo elige solo el mod `esfuerzo-auto` en cada prompt; el usuario puede fijarlo con `/esfuerzo`.
- Los skills `ecc-*` y la mayoría de los demás son manuales (`/nombre`): no los busques ni los sugieras salvo que el usuario los nombre.
