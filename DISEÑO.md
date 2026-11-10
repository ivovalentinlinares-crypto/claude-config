# Diseño: eficiente, sin perder inteligencia, automático

Reemplaza al plan del 2026-11-07. Sale de medir los transcripts de Consorcio (15 sesiones, 1 al 9 de noviembre de 2026, todas en la app de escritorio) con `scripts/medir-tokens.py`.

## Lo que se midió

Los porcentajes son de costo: cada token pesa según su precio relativo (lectura de caché ×0,1; escritura ×1,25 a 5 minutos o ×2 a 1 hora; salida ×5).

| Qué | Resultado |
|---|---|
| Quién gasta | hilo principal 64 % (casi todo Opus), subagentes 32 %, workflows 4 % |
| En qué | releer la conversación desde caché 60 %, escribir caché 23 %, salida 17 % (el pensamiento, ~7 %) |
| Contexto por pedido | mediana 281k, p90 690k; la ventana es de 1M y compactaba al 80 % |
| Tope simulado | 200k: hasta −25 % del total; 150k: hasta −31 % (sin contar el costo de compactar, ~2-3 %) |
| Caché rehecha | 11 % del hilo principal; 23 de 26 casos, tras más de una hora de pausa |
| Caché de 5 min | sería 12 % peor: hubo 92 pausas de 5 a 60 minutos con 297k de contexto medio |
| Cambiar el esfuerzo | no rompe la caché (6 de 6). Cambiar de modelo sí |
| Subagentes | 23 llamadas; `codigo-dificil` (Opus), 5 corridas = 17 % del total, hasta 463k de contexto |
| Contexto inicial | 81k de mediana; controlables ~20k (skills, agentes, hooks) |
| Salida de herramientas | Bash 74 % (`sed` 36 %, `grep` 18 %, `cat` 16 %), Read 19 %; cargo no figura |
| Precio | Opus ≈ 1,65 veces Sonnet por token |
| context-mode | 34 usos reales, 1467 errores de su hook, +2,4k por sesión y por agente, bloqueaba WebFetch |

**Conclusión:** la palanca es el tamaño del contexto, no el modelo. Bajar el hilo principal a Sonnet ahorraría ~40 % de esa parte perdiendo inteligencia; topear el contexto ahorra más y, con un buen resumen, no la pierde (un contexto chico además se atiende mejor).

## Las decisiones

| Problema | Mecanismo |
|---|---|
| Contexto enorme por pedido | `autoCompactWindow: 200000` global |
| Subagentes Opus que crecen sin límite | `autoCompactWindow: 150000` y `maxTurns` en cada agente |
| Perder el hilo al compactar | hook `PreCompact` (qué conservar) y `SessionStart` en `compact`/`resume` (estado real del repo y `PROGRESO.md`); el `CLAUDE.md` del proyecto se relee solo y trae `# Compact instructions` |
| Caché rehecha por cambio de modelo | `model: opus` fijo (no `opusplan`); el modelo se elige por agente, el esfuerzo por prompt con `esfuerzo-auto` |
| Leer archivos enteros con `sed`/`cat` | reglas de lectura en `CLAUDE.md` y en cada agente; LSP de rust-analyzer |
| Peso fijo | sin context-mode, sin skill-creator duplicado, 4 agentes menos (Explore propio, verificador, codigo-facil, rust-build-resolver), skills de documentos `name-only` |
| Verificar sin pedirlo | hook `Stop` por proyecto: formatea y corre clippy solo si cambió Rust desde la última vez, y devuelve solo los errores |
| Lo irreversible | hook que frena commit en `main`, push a `main` y `gh pr merge` sin el usuario presente; migraciones ya commiteadas bloqueadas en Consorcio |

## Qué no se cambió y por qué

- **Opus en el hilo principal y el esfuerzo automático:** el pensamiento es ~7 % del gasto; recortarlo baja calidad por poco ahorro.
- **Caché de 1 hora:** la de 5 minutos sale más cara con estas pausas.
- **Skills manuales:** con `disable-model-invocation` no ocupan contexto.
- **opencode:** sigue igual; solo heredó la tabla de agentes nueva.

## Medir

```bash
scripts/medir-tokens.py Consorcio --comparar '2026-11-09 23:51'
```

Separa las sesiones por la hora en que arrancaron (la config nueva se instaló el 9 de noviembre a las 23:51): una sesión abierta antes sigue con la config vieja aunque se use después. Línea de base: contexto mediano por pedido 288k · subagentes Opus 26,5 % · caché rehecha 11 % del hilo principal · contexto inicial 83k. Si a la semana el contexto mediano no bajó de ~150k, revisar que la ventana se esté aplicando (`/context` en una sesión).

**Prueba opcional, después de medir:** una semana de sesiones de rutina con Sonnet 5.5 en el hilo principal y Opus como advisor (`/advisor opus`), y comparar.
