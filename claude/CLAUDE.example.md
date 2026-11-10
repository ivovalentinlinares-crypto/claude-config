# Memoria: una sola nota índice (Obsidian u otra carpeta de Markdown)
<!-- Cambiá MEMORIA por la ruta de tu vault, por ejemplo ~/Documentos/Obsidian Vault/Memoria -->
La única memoria de largo plazo es `MEMORIA/`. No uses la memoria nativa (`MEMORY.md`) ni otros plugins de memoria: lo duradero va ahí, que el usuario también lee y edita.

- **Solo si la tarea lo necesita.** Leé `MEMORIA/Indice.md` cuando la tarea toque un proyecto, un tema o una decisión anterior que podría estar anotada, cuando el usuario mencione algo de antes o cuando vayas a escribir una nota. Para preguntas sueltas o cambios chicos, no lo abras. `MEMORIA/Preferencias.md` solo si la tarea depende de cómo le gusta trabajar al usuario.
- **Después, solo lo del tema.** Abrí únicamente las notas del índice que coinciden con la tarea. Nunca leas el vault entero; si algo no está en el índice, buscalo por nombre de archivo.
- **Nunca** abras carpetas de credenciales salvo que el usuario lo pida, ni copies claves, tokens o contraseñas a una nota.
- **Al terminar** algo que valga la pena, escribí una nota (una nota = un hecho) y agregala al índice con una línea: si no está en el índice, no se vuelve a encontrar.

# Grafo antes de leer (graphify, opcional)
Antes de explorar un proyecto, buscá `.graphify/graph.json` en su raíz. Si existe, consultalo primero (`graphify query "<pregunta>"`) y abrí solo los archivos que señale. Si no existe y el proyecto es grande (más de ~50 archivos de código), crealo con `/graphify <ruta>`. En proyectos chicos, leelos directo. Nunca incluyas `.env` ni claves en el grafo.

# Delegación y contexto
Lo que más gasta es el tamaño de la conversación: cada pedido la reenvía entera. Elegí el agente sin preguntar:

| Agente | Modelo | Cuándo |
|---|---|---|
| `codigo-medio` | Sonnet, medio | tarea común en 1 a 3 archivos, bug con causa clara, tests, renombres, un error de compilación |
| `codigo-dificil` | Opus, alto | varios módulos, async, bug de causa desconocida, ejecutar el plan de `arquitecto` |
| `codigo-experto` | Opus, muy alto | refactor grande, concurrencia, seguridad, migraciones, algo que ya falló |
| `arquitecto` | Opus, max | diseñar antes de programar algo grande o crítico (no edita) |

- Lo que se resuelve en pocos pasos (una edición, leer 1 o 2 archivos, un comando) hacelo directo: un subagente tarda en arrancar.
- Delegá lo que va a leer mucho que después no hace falta acá: buscar o entender código en más de ~5 archivos va a `Explore`; una implementación larga, al agente de su nivel. El brief lleva rutas, qué está hecho y qué es terminar; pedí un informe corto.
- Rust: revisar con `rust-reviewer`. Red, DNS, rutas o servers que no se ven: `network-troubleshooter` (solo lectura).
- Leé fragmentos: Read con `offset`/`limit`, `rg -n`, o el LSP (rust-analyzer) para definiciones y referencias. No hagas `cat` ni `sed -n` de archivos enteros, ni vuelvas a leer lo que ya está en la conversación.
- Filtrá las salidas largas (builds, tests, logs) antes de que entren: `| tail -40`, `rg -m 20 error`.
- Si un proyecto tiene un hook `Stop` que compila al terminar y te devuelve errores, arreglalos antes de cerrar.
- La conversación compacta sola a los 200k tokens y el hook de compactación conserva pedidos, decisiones y pendientes. Lo que tiene que sobrevivir a la sesión va al `PROGRESO.md` del proyecto.
- El razonamiento del hilo principal lo elige solo el mod `esfuerzo-auto` en cada prompt; el usuario puede fijarlo con `/esfuerzo`. No cambies de modelo a mitad de sesión: la caché es por modelo y se rehace entera.
- Los skills `ecc-*` y la mayoría de los demás son manuales (`/nombre`): no los busques ni los sugieras salvo que el usuario los nombre.

