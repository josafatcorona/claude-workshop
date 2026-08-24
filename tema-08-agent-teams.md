# Agent Teams y Comunicación Peer-to-Peer

**Ejercicio 8 - 20 minutos**

---

## Objetivo

Configurar un equipo de agents especializados que se pasan trabajo por etapas, y entender exactamente qué rutas de comunicación existen entre ellos —y cuáles no.

## Contexto

Los subagents del Tema 7 son "ejecutores": cada uno hace su tarea y reporta. Un Agent Team va un paso más allá: varios agents especializados encadenados en un pipeline de N etapas, cada uno con su propio modelo, sus propias herramientas y su propia ventana de contexto.

### Diferencia Clave
- **Tema 7 (Subagents):** delegación puntual — "analiza esto y dime"
- **Tema 8 (Agent Teams):** un flujo con etapas, donde el resultado de cada agent es la entrada del siguiente

## Conceptos Clave

- **Agent Team:** conjunto de agents especializados que colaboran en un mismo flujo
- **SendMessage:** herramienta para enviar mensajes a un agent alcanzable
- **Coordinador:** el agente principal, que releva el payload de una etapa a la siguiente
- **Handoff:** transferencia de una tarea completa (con su contexto) de un agent a otro
- **ListAgents:** descubrir qué agents son alcanzables ahora mismo

---

## Nota Previa: Cómo se Comunican los Agents de Verdad

Léelo antes de escribir el primer agent. Estas cinco reglas evitan el 90% de los tropiezos
del ejercicio.

### 1. `message` es un string, no un objeto

La firma real de la herramienta es:

```json
{"to": "transformer", "summary": "resumen corto", "message": "texto plano"}
```

Así que al enviar un payload JSON hay que serializarlo:

```javascript
SendMessage({
  to: "a18048adb026a856f",
  summary: "12 filas extraidas, listas para transformar",
  message: JSON.stringify({
    action: "START_TRANSFORM",
    data_file: "/tmp/extracted_data.csv",
    row_count: 12
  })
})
```

| Campo | Tipo | Para qué sirve |
|---|---|---|
| `to` | string | `agentId` del destino (o `"main"` para la conversación principal) |
| `message` | string | El contenido: JSON serializado, o prosa |
| `summary` | string | 5-10 palabras; es el preview de una línea que ve el usuario en la UI |

> **En la práctica, prosa estructurada funciona igual de bien que JSON** — el receptor es un
> modelo, no un parser. Usamos JSON en este tema porque impone disciplina y hace evidente qué
> información no se puede omitir. Elige según tu caso.

### 2. El `agentId` es la dirección, no el nombre del type

`extractor` es el nombre de una **definición** (`.claude/agents/extractor.md`). La dirección
de una **instancia** es el `agentId` que devuelve el spawn:

```
SendMessage({to: "transformer", ...})       → No agent named 'transformer' is reachable
SendMessage({to: "a18048adb026a856f", ...}) → Resuming agent a18048a   ✓
```

Fíjate en `Resuming`: un agent que ya terminó **sigue siendo reanudable** desde su transcript.
Eso es lo que hace viable el pipeline.

### 3. Los subagents hermanos no son peers entre sí

Cuando el agente principal lanza cuatro agents, los cuatro son **hermanos** — hijos del
principal, no peers. Un `SendMessage` de uno a otro falla con `"no reachable"`.

**El peer-to-peer real de `SendMessage` existe entre *sesiones* de Claude Code** — dos
terminales abiertas, o sesiones en la nube, que se descubren con `ListAgents`. Dentro de una
misma sesión, la ruta es el coordinador.

```
extractor  ──payload──►  [principal]  ──SendMessage(agentId)──►  transformer
transformer ─payload──►  [principal]  ──SendMessage(agentId)──►  loader
loader ─────payload──►  [principal]  ──SendMessage(agentId)──►  quality-checker
```

Por eso, en este ejercicio, **cada agent devuelve en su resultado final el payload JSON
destinado al siguiente**, y el coordinador lo releva.

### 4. Un agent no espera mensajes

No existe primitiva de espera. Un agent ejecuta su prompt y termina. Si lanzas cuatro agents
en paralelo y tres no tienen nada que hacer todavía, esos tres terminan en segundos:

```
transformer      → "no he recibido START_TRANSFORM"   → termina
loader           → "no he recibido START_LOAD"        → termina
quality-checker  → "aguardando mensajes"              → termina
extractor        → (leer, contar, copiar)             → termina con su payload
```

Por eso **lanzamos cada etapa cuando le toca**, no todas de golpe.

### 5. Encolado ≠ entregado

Un mensaje a un agent vivo responde `Message queued for delivery at its next tool round`. Si
el agent termina su turno antes de ese round, el mensaje no se procesa. Verifica siempre que
la etapa produjo su artefacto antes de dar por buena la entrega — y para flujos serios,
implementa la *dead letter queue* del Tip Avanzado.

---

## Paso 0: Crear Directorio de Agents (Si no existe)

```bash
# Crear estructura de directorios
mkdir -p .claude/agents
mkdir -p .claude/skills
```

Y genera los datos de práctica que usará el pipeline:

```bash
./generar-datos-muestra.sh .        # crea data/ventas_2024.csv y output/
```

---

## Paso 1: Crear Agents Base - Extractor

**Crear archivo:** `.claude/agents/extractor.md`

```bash
touch .claude/agents/extractor.md
```

**Contenido de `.claude/agents/extractor.md`:**

```markdown
---
name: extractor
description: Extrae datos de fuentes configuradas
model: claude-sonnet-5
tools:
  - Bash
  - Read
  - SendMessage
teammates:
  - transformer
  - quality-checker
---

# Extractor Agent

## Responsabilidad
Extraer datos de la fuente indicada y dejarlos listos para transformación.

## Proceso

1. Leer la configuración que te llega en el prompt inicial (ruta y tipo de fuente)
2. Leer la fuente de datos
3. Validar lo mínimo: header presente, columnas esperadas, conteo de filas
4. Guardar los datos extraídos en `/tmp/extracted_data.csv`
5. Devolver el payload de traspaso

## Cómo Entregas tu Trabajo

Tus teammates son agents hermanos: NO son alcanzables desde tu contexto, así que
no intentes `SendMessage` a ellos. **Tu canal de salida es tu resultado final.**
Termina devolviendo exactamente este JSON:

    {
      "action": "START_TRANSFORM",
      "data_file": "/tmp/extracted_data.csv",
      "row_count": 12,
      "columns": ["fecha","producto","categoria","region","cantidad","precio_unitario"],
      "issues": []
    }

Si detectas problemas de calidad, decláralos en `issues` — el coordinador se los
pasa al quality-checker:

    "issues": [
      { "stage": "extraction",
        "type": "null_values_found",
        "detail": "1 fila con cantidad vacia (2024-01-15)",
        "severity": "warning" }
    ]

## Flujo Esperado
- Ejecutas tu prompt de una sola pasada; no esperas mensajes de nadie
- El coordinador releva tu payload al transformer
- Deja `/tmp/extracted_data.csv` intacto como copia de lo extraído
```

> **Sobre `teammates:`** — documenta el grafo del pipeline: con quién se supone que colabora
> este agent. Es una convención de documentación, no una ruta de red; lo vemos en detalle en
> el Paso 4.

---

## Paso 2: Crear Transformer Agent

**Crear archivo:** `.claude/agents/transformer.md`

```bash
touch .claude/agents/transformer.md
```

**Contenido:**

```markdown
---
name: transformer
description: Transforma y enriquece datos extraídos
model: claude-sonnet-5
tools:
  - Bash
  - Read
  - Write
  - SendMessage
teammates:
  - extractor
  - loader
  - quality-checker
---

# Transformer Agent

## Responsabilidad
Aplicar limpieza y transformaciones a los datos extraídos.

## Proceso de Transformación

1. Leer el payload `START_TRANSFORM` que te entrega el coordinador en tu prompt
2. Leer el archivo indicado en `data_file`
3. Aplicar limpieza: normalizar fechas a ISO, eliminar duplicados exactos,
   decidir qué hacer con valores faltantes (documenta la decisión)
4. Escribir el resultado en `/tmp/transformed_data.csv`
5. Devolver el payload de traspaso

## Lo que Recibes

    {
      "action": "START_TRANSFORM",
      "data_file": "/tmp/extracted_data.csv",
      "row_count": 12
    }

## Cómo Entregas tu Trabajo

No intentes `SendMessage` al loader: es un agent hermano, no alcanzable desde tu
contexto. Devuelve este JSON como resultado final:

    {
      "action": "START_LOAD",
      "data_file": "/tmp/transformed_data.csv",
      "rows_in": 12,
      "row_count": 11,
      "transformations_applied": [
        "normalized_dates",
        "removed_duplicates",
        "dropped_rows_missing_cantidad"
      ],
      "decisions": [
        { "row": "2024-01-15 Mouse Inalambrico",
          "action": "dropped",
          "reason": "cantidad vacia; imputarla falsearia el GMV" }
      ]
    }

## Si Algo No Cuadra

No puedes preguntarle al extractor. Declara la duda en el payload y deja que el
coordinador decida:

    {
      "action": "CLARIFY",
      "issue": "column_missing",
      "details": "Se esperaba la columna 'timestamp' y no aparece"
    }
```

---

## Paso 3: Crear Loader Agent

**Crear archivo:** `.claude/agents/loader.md`

```bash
touch .claude/agents/loader.md
```

**Contenido:**

```markdown
---
name: loader
description: Carga datos a destino final
model: claude-sonnet-5
tools:
  - Bash
  - Read
  - Write
  - SendMessage
teammates:
  - transformer
  - extractor
  - quality-checker
---

# Loader Agent

## Responsabilidad
Cargar los datos transformados a su destino final.

## Proceso de Carga

1. Leer el payload `START_LOAD` que te entrega el coordinador
2. Validar la integridad del archivo (existe, tiene header, conteo esperado)
3. Cargar a `output/ventas_cargadas.csv`, añadiendo la columna calculada
   `total = cantidad * precio_unitario`
4. Verificar que las filas cargadas coinciden con las esperadas
5. Devolver el payload de verificación

## Lo que Recibes

    {
      "action": "START_LOAD",
      "data_file": "/tmp/transformed_data.csv",
      "row_count": 11
    }

## Cómo Entregas tu Trabajo

Devuelve este JSON como resultado final:

    {
      "action": "VERIFY_LOAD",
      "destination": "output/ventas_cargadas.csv",
      "rows_expected": 11,
      "rows_loaded": 11,
      "status": "SUCCESS"
    }

## En Caso de Error

No abortes en silencio: devuelve el fallo con el mismo formato, para que el
coordinador pueda escalarlo o reintentar.

    {
      "action": "LOAD_FAILED",
      "error": "No existe /tmp/transformed_data.csv",
      "rows_attempted": 11,
      "rows_loaded": 0,
      "status": "FAILED"
    }
```

---

## Paso 4: Crear Quality Checker Agent (Supervisor)

**Crear archivo:** `.claude/agents/quality-checker.md`

```bash
touch .claude/agents/quality-checker.md
```

**Contenido:**

```markdown
---
name: quality-checker
description: Valida calidad de datos en todas las etapas
model: claude-haiku-4-5-20251001
tools:
  - Bash
  - Read
  - SendMessage
teammates:
  - extractor
  - transformer
  - loader
authority: can-block
---

# Quality Checker Agent

## Responsabilidad
Validar la calidad de cada etapa y bloquear el pipeline si hay problemas críticos.

## Qué Validar

### Fase de Extracción
- ✓ Row count dentro del rango esperado (5-10000 filas)
- ✓ Todas las columnas esperadas presentes
- ✓ No valores NULL en columnas clave
- ✓ Tipos de datos coinciden

### Fase de Transformación
- ✓ Sin pérdida de datos injustificada (`rows_in ≈ row_count`)
- ✓ Duplicados removidos correctamente
- ✓ Fechas normalizadas correctamente
- ✓ Cada fila descartada tiene su justificación en `decisions`

### Fase de Carga
- ✓ Integridad referencial mantenida
- ✓ `rows_loaded == rows_expected`
- ✓ La columna calculada `total` cuadra
- ✓ No duplicados en destino

## Cómo Entregas tu Veredicto

Recibes del coordinador el payload de la etapa a validar. Devuelve siempre este
JSON como resultado final — un solo veredicto por etapa:

    {
      "action": "VALIDATION_RESULT",
      "stage": "extraction",
      "verdict": "PASSED",
      "checks_passed": 4,
      "checks_failed": [],
      "notes": "1 fila con cantidad vacia; el transformer debe decidir"
    }

Si detectas un problema CRÍTICO, **bloquea**: el coordinador debe detener el
pipeline y no lanzar la siguiente etapa.

    {
      "action": "VALIDATION_RESULT",
      "stage": "extraction",
      "verdict": "BLOCKED",
      "checks_passed": 2,
      "checks_failed": ["row_count_out_of_range"],
      "reason": "12 filas, fuera del rango esperado 100-10000",
      "recommendation": "Revisar la fuente o ajustar el rango esperado",
      "severity": "CRITICAL"
    }

## Escalación

Si el mismo problema aparece 3+ veces, no sigas reintentando: escala al humano.

    {
      "action": "ESCALATE",
      "reason": "Fallos de validacion repetidos en la misma etapa",
      "failed_attempts": 3,
      "recommendation": "Revision manual - posible corrupcion en la fuente"
    }
```

### Sobre `authority: can-block` — Qué es Real y Qué es Convención

Detente aquí un momento, porque este campo enseña algo importante sobre cómo funcionan
realmente los agents.

**El frontmatter que Claude Code interpreta es:** `name`, `description`, `tools` y `model`.
Cualquier otra clave —`authority` y `teammates` incluidas— no crea comportamiento en el
runtime.

Compruébalo tú mismo: pídele a Claude que liste los agents disponibles. Verás
`quality-checker` con su description, sus tools y su model. De `authority` no queda rastro.
Y `teammates:` **no crea rutas de mensajería**: un `SendMessage` a un hermano listado ahí
falla igual con `"no reachable"`.

**Entonces, ¿por qué funciona?** Porque el agent lee su propio prompt. `authority: can-block`
es una **convención semántica**: le comunica al modelo "tú tienes potestad de detener esto".
El bloqueo es **cooperativo** — ocurre porque el modelo coopera, no porque el runtime lo
imponga.

Eso no lo hace inútil: documentar roles y colaboradores en el frontmatter es buena práctica y
el modelo efectivamente los respeta. Pero hay que saber qué garantía tienes. Otros valores que
puedes documentar con la misma lógica:

| Valor | Convención |
|---|---|
| `can-block` | Detiene el flujo ante un fallo crítico |
| `advisory` | Solo reporta, nunca detiene |
| `can-escalate` | Sube al humano tras N fallos |
| `can-retry` | Reintenta con parámetros ajustados |
| `read-only` | Nunca escribe |

**La autoridad que SÍ es real está en `tools:`.** Nuestro `quality-checker` no tiene `Write`
ni `Edit` — literalmente no puede modificar datos, coopere o no. Eso es enforcement del
runtime, no una promesa.

**Y si necesitas bloqueo garantizado, eso no es trabajo de un agent — es un hook.** El
`PreToolUse` del Tema 4 lo ejecuta el harness, y su exit code 2 detiene la herramienta
quiera o no el modelo.

```
┌───────────────┬──────────────────────────┬─────────────────────────┐
│ MECANISMO     │ PARA QUÉ                 │ TIPO DE GARANTÍA        │
├───────────────┼──────────────────────────┼─────────────────────────┤
│ HOOK          │ Cosas que SIEMPRE pasan  │ Bloqueo GARANTIZADO     │
│ tools:        │ Qué puede tocar el agent │ Bloqueo ESTRUCTURAL     │
│ authority:    │ Rol dentro del team      │ Bloqueo COOPERATIVO     │
└───────────────┴──────────────────────────┴─────────────────────────┘
```

**Diseño robusto = las tres capas.** El `quality-checker` valida (cooperativo), no tiene
Write (estructural), y un hook `PreToolUse` puede vetar escrituras a la tabla de producción
si la validación no pasó (garantizado).

---

## Paso 5: Patrón de Handoff (Avanzado)

### ¿Dónde va este código?

Pregunta frecuente, y la respuesta desbloquea el patrón: **el handoff no es un archivo nuevo
ni código ejecutable suelto.** Es un *formato de payload* que documentas **dentro del body de
un agent `.md`**, en su sección "Cómo Entregas tu Trabajo". Es el mismo traspaso de los
Pasos 1-4, solo que con un contenido mucho más rico.

**Es opcional.** El pipeline de este ejercicio funciona sin él. Pero resuelve un problema
concreto que conviene entender.

### Notificación vs. Handoff

| | Notificación (Pasos 1-4) | Handoff (este paso) |
|---|---|---|
| **Payload** | `{data_file, row_count}` | + qué se hizo, qué falta, restricciones, artifacts |
| **Supuesto** | El receptor ya sabe su trabajo | El receptor **no tiene tu contexto** |
| **Tarea** | Predefinida y fija | Abierta ("limpia esto, tú decides cómo") |
| **Emisor** | Ya terminó; su payload es rutinario | **Termina** transfiriendo la responsabilidad entera |

La razón de fondo: **cada agent corre en su propia ventana de contexto**. El `transformer` no
ve *nada* de lo que hizo el `extractor` — ni los archivos que leyó, ni las decisiones que
tomó, ni los errores que sorteó por el camino.

Si la tarea del receptor está fija de antemano, tres campos bastan. Si el receptor tiene que
**decidir** algo, necesita el contexto completo o improvisará a ciegas.

**Formato de Handoff:**

```json
{
  "action": "HANDOFF",
  "task_description": "Descripción completa de qué hay que hacer",
  "context": {
    "what_was_done": [
      "Extracted data from PostgreSQL",
      "Validated schema"
    ],
    "what_remains": [
      "Clean and transform data",
      "Load to warehouse"
    ],
    "important_constraints": [
      "Must preserve date formatting",
      "Customer IDs are sensitive"
    ]
  },
  "artifacts": [
    {
      "path": "/tmp/extracted_data.csv",
      "description": "Raw extracted data - 1000 rows",
      "checksum": "abc123"
    },
    {
      "path": "/tmp/schema.json",
      "description": "Expected schema and types"
    }
  ],
  "timeout_minutes": 30,
  "priority": "HIGH"
}
```

**Después del handoff, el agent que delegó finaliza su tarea.** No se queda esperando
respuesta: transfirió la responsabilidad completa.

### Dónde ponerlo en TU ejercicio

En `.claude/agents/extractor.md`, como **alternativa** al `START_TRANSFORM` estándar. Añade
esta sección al body del agent:

```markdown
## Handoff Completo (cuando la transformación no es rutinaria)

Normalmente devuelves START_TRANSFORM. Pero si detectas que los datos requieren
limpieza NO estándar (schema inesperado, formatos mixtos, reglas de negocio
ambiguas), devuelve un HANDOFF: el coordinador se lo pasa entero al transformer.

    {
      "action": "HANDOFF",
      "task_description": "Limpiar ventas_2024.csv - formatos de fecha mixtos",
      "context": {
        "what_was_done": ["Leido el CSV", "Schema validado parcialmente"],
        "what_remains": ["Normalizar 3 formatos de fecha distintos", "Cargar a destino"],
        "important_constraints": ["No inventes valores para cantidad vacia"]
      },
      "artifacts": [
        { "path": "/tmp/extracted_data.csv", "description": "12 filas crudas" }
      ]
    }
```

Cuando el receptor **sí** es alcanzable —otra sesión de Claude Code, o un subagent que tú
mismo lanzaste— el mismo payload viaja por `SendMessage`, serializado:

```javascript
SendMessage({
  to: "a18048adb026a856f",                       // agentId, no el nombre del type
  summary: "Handoff: datos requieren limpieza no estandar",
  message: JSON.stringify({ action: "HANDOFF", /* ... */ })
})
```

> **Regla para decidir:** si puedes describir el trabajo del receptor en una sola línea de tu
> propio prompt, usa una notificación. Si necesitas explicarle *por qué* y *bajo qué
> restricciones*, usa un handoff.

---

## Paso 6: Descubrir Agents - `/agents` y `ListAgents`

Son dos cosas distintas, y confundirlas es el tropiezo más común del tema:

| | Qué muestra |
|---|---|
| `/agents` | Las **definiciones** cargadas: los `.md` de `.claude/agents/`, con su model y tools |
| `ListAgents` | Las **instancias vivas** ahora mismo, con su `agentId` |

Antes de lanzar nada, `ListAgents` está vacío — y eso es correcto, no un error:

```
No reachable agents
```

Los `.md` son *tipos* de agent, no procesos. Después de lanzar la primera etapa:

```javascript
await ListAgents()

// extractor    a18048adb026a856f   completed
// transformer  c47f21b9de034117    running
```

Esos `agentId` son las direcciones que necesitas para reanudar una instancia con
`SendMessage`. `ListAgents` también lista **otras sesiones de Claude Code** alcanzables — ahí
sí hay peer-to-peer real.

---

## Paso 7: Crear el Skill Coordinador

**Crear archivo:** `.claude/skills/run-pipeline/SKILL.md`

```bash
mkdir -p .claude/skills/run-pipeline
touch .claude/skills/run-pipeline/SKILL.md
```

**Contenido:**

```markdown
---
name: run-pipeline
description: Ejecuta el pipeline de datos completo con todos los agents
---

# Run Pipeline Skill

Coordina el pipeline ETL de extremo a extremo. **Tú, el agente principal, eres el
coordinador**: los agents del team no se alcanzan entre sí, así que tú relevas el
payload de cada etapa a la siguiente.

## 0. Preparar datos

Verifica que existe `data/ventas_2024.csv`. Si no:
`./generar-datos-muestra.sh .`

## 1. Extracción

Lanza el extractor con el Agent tool (el parámetro del tipo es `subagent_type`):

    Agent({
      description: "Extraer ventas_2024",
      subagent_type: "extractor",
      prompt: "Extrae data/ventas_2024.csv (CSV; ojo: hay una linea vacia antes " +
              "del header). Guardalo en /tmp/extracted_data.csv y devuelve el " +
              "payload START_TRANSFORM."
    })

Del resultado guarda DOS cosas: el **payload JSON** y el **agentId**.

## 2. Validar la extracción

    Agent({
      description: "Validar extraccion",
      subagent_type: "quality-checker",
      prompt: "Valida la etapa de extraccion con este payload: <payload del paso 1>"
    })

Si el veredicto es `BLOCKED`, **detente aquí** y reporta al usuario. No lances la
siguiente etapa.

## 3. Transformación

    Agent({
      description: "Transformar datos",
      subagent_type: "transformer",
      prompt: "Aplica la transformacion. Payload de entrada: <payload del paso 1>"
    })

## 4. Validar la transformación

Igual que el paso 2, con `stage: "transformation"`.

## 5. Carga

    Agent({
      description: "Cargar a destino",
      subagent_type: "loader",
      prompt: "Carga los datos. Payload de entrada: <payload del paso 3>"
    })

## 6. Validación final

Valida `stage: "load"` y reporta al usuario la tabla de conteos por etapa.

## Reanudar una instancia ya lanzada

Si necesitas volver a hablar con un agent (por ejemplo, pedirle un reintento tras
un BLOCK), usa su `agentId` — no el nombre del type — y recuerda que `message` es
un string:

    SendMessage({
      to: "a18048adb026a856f",                  // agentId devuelto por el spawn
      summary: "Reintenta extraccion con validacion de schema",
      message: JSON.stringify({
        action: "RETRY",
        reason: "Quality check fallo: row_count fuera de rango",
        attempt: 2
      })
    })

Un agent terminado sigue siendo reanudable (`Resuming agent ...`).

## Traza del flujo

    extractor → [tú] → quality-checker → [tú] → transformer → [tú]
              → quality-checker → [tú] → loader → [tú] → quality-checker
```

---

## Paso 8: Ejecutar el Flujo Final

Ya tienes los 4 agents y el skill. **¿Cómo lo corres?**

```
/run-pipeline
```

Eso es todo. Y conviene detenerse un segundo, porque los bloques de código del SKILL.md
**no son código que se ejecute**. Un skill son *instrucciones para el agente principal*:
Claude lee el SKILL.md y hace las llamadas reales a `Agent(...)` y `SendMessage(...)`. Nadie
interpreta ese pseudocódigo.

### Qué observar mientras corre

**1. `ListAgents` vacío al principio.** Antes de lanzar nada devuelve `No reachable agents`.
Es lo esperado: aún no hay instancias. Para ver las definiciones cargadas, `/agents`.

**2. Cada etapa termina en cuanto entrega su payload.** Ningún agent se queda esperando; por
eso el coordinador lanza la siguiente etapa cuando tiene el payload de la anterior.

**3. El coordinador es visible en la traza.** Verás alternarse `Agent(...)` y la lectura del
payload devuelto. Ese ida y vuelta *es* el pipeline.

**4. Los artefactos aparecen en disco en orden.** `/tmp/extracted_data.csv`, luego
`/tmp/transformed_data.csv`, luego `output/ventas_cargadas.csv`.

### Resultado esperado end-to-end

```
etapa            filas   artefacto
─────────────────────────────────────────────────────────
extracción         12    /tmp/extracted_data.csv
transformación     11    /tmp/transformed_data.csv     (descarta 1: cantidad vacía)
carga              11    output/ventas_cargadas.csv    (+ columna total)
```

La fila descartada es el valor faltante sembrado a propósito en `ventas_2024.csv`. Fuerza una
decisión real del quality-checker: su regla dice *"sin pérdida de datos injustificada"*, pero
el dato es irrecuperable. Lo esperable es un **PASSED** con la justificación de que `cantidad`
es necesaria para el GMV y no se puede imputar sin arbitrariedad — y una nota de que en
producción hace falta una política explícita de imputación vs. descarte. Ese razonamiento *es*
el entregable del ejercicio, no el CSV.

### Cómo comprobarlo — 4 niveles

```bash
# 1. Definiciones cargadas        → /agents      (los 4, con model y tools)
# 2. Instancias vivas             → ListAgents   (running / completed + agentId)
# 3. Artefactos y conteos
wc -l /tmp/extracted_data.csv /tmp/transformed_data.csv output/ventas_cargadas.csv
# 4. Veredicto del quality-checker: PASSED o BLOCKED por cada etapa
```

Para el nivel 3, que los conteos cuadren: `extraídas ≥ transformadas == cargadas`.

### Variante: provocar un BLOCK

Sube el rango esperado de filas a `100-10000` en `quality-checker.md` y vuelve a correr. Con
12 filas el veredicto será `BLOCKED` y el coordinador debe **detener el pipeline** ahí mismo.
Es la forma de comprobar el ítem "bloqueos del quality-checker detienen el pipeline" —
y de ver que el bloqueo es cooperativo: funciona porque el coordinador respeta el veredicto.

### Variante: transformaciones con efecto real

Con `ventas_2024.csv`, el transformer reporta `removed_duplicates` y `normalized_dates`… y
ninguna hace nada (ya está en ISO, sin duplicados). Para que el pipeline haga trabajo
observable, usa el dataset sucio que genera el script:

```
data/ventas_2024_dirty.csv   17 filas → 14 tras limpiar
                             3 formatos de fecha, 2 duplicados exactos, 2 valores vacíos
```

---

## Diagrama de Comunicación

```
┌──────────────────────────────────────────────────────────────┐
│                        AGENT TEAM                            │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│    ┌───────────┐   ┌─────────────┐   ┌──────────┐            │
│    │ EXTRACTOR │   │ TRANSFORMER │   │  LOADER  │            │
│    │  (Sonnet) │   │  (Sonnet)   │   │ (Sonnet) │            │
│    └─────┬─────┘   └──────┬──────┘   └────┬─────┘            │
│          │ payload        │ payload       │ payload          │
│          ▼                ▼               ▼                  │
│    ╔══════════════════════════════════════════════╗          │
│    ║      COORDINADOR  (el agente principal)      ║          │
│    ║   releva cada payload a la etapa siguiente   ║          │
│    ╚══════════════════════════════════════════════╝          │
│          │                ▲                                  │
│          │ valida etapa   │ veredicto PASSED / BLOCKED       │
│          ▼                │                                  │
│    ┌──────────────────────┴───────────────────────┐          │
│    │            QUALITY CHECKER (Haiku)           │          │
│    │   sin Write en tools → no puede tocar datos  │          │
│    └──────────────────────────────────────────────┘          │
│                                                              │
│  Los 4 agents son HERMANOS: no se alcanzan entre sí.         │
│  El peer-to-peer real de SendMessage es ENTRE SESIONES.      │
└──────────────────────────────────────────────────────────────┘
```

---

## Casos de Uso Reales en Desarrollo de Código

El ejemplo ETL de este tema es didáctico. Estos son los casos donde un Agent Team realmente
paga su costo en trabajo de desarrollo — recuerda que **cada agent es una ventana de
contexto adicional**, así que tiene que ganarse el gasto.

### Alto valor

**1. Migración a escala**
Un agent descubre todos los call sites; N agents transforman en paralelo (cada uno en su
propio worktree para no pisarse); un verifier corre los tests. Este es *el* caso canónico:
el trabajo no cabe en un solo contexto, y el paralelismo es real.

**2. Code review con perspectivas independientes**
`security-reviewer`, `perf-reviewer` y `test-coverage-reviewer` revisan el mismo diff **sin
verse entre sí**, y un `verifier` intenta *refutar* cada hallazgo antes de reportarlo.
La independencia es el punto entero: un solo agente ancla sus conclusiones en lo primero que
encontró y deja de buscar.

**3. Implementar → probar → arreglar en loop**
`implementer` escribe el código y hace handoff a `tester`, que rebota los fallos de vuelta.
Clave: el tester **no debe ver** el razonamiento del implementer. Si lo ve, hereda sus puntos
ciegos y valida los mismos supuestos equivocados.

**4. Debug de sistemas distribuidos**
Un agent por servicio o por fuente de logs, cada uno con contexto de su dominio,
correlacionando hallazgos a través del coordinador. Ningún contexto único aguanta los logs de
cinco servicios a la vez.

**5. Pipeline de datos real (nuestro ejercicio, a escala)**
Con 1000 archivos, el coordinador puede lanzar la extracción del archivo N+1 mientras el
transformer aún trabaja en el N. Con un solo agente secuencial esperarías cada paso.

### Bajo valor — usa un subagent normal, o nada

- Refactors de un solo archivo
- Features pequeñas y bien definidas
- **Cualquier flujo donde el paso B necesite ver *todo* lo del paso A** — ahí el aislamiento
  de contexto es puro costo, sin beneficio

### La regla para decidir

> **Un Agent Team gana cuando el aislamiento de contexto es una VENTAJA** — independencia de
> criterio, paralelismo real, o volumen que no cabe en una ventana.
> **Pierde cuando el aislamiento es un obstáculo a superar.**

Si te encuentras diseñando handoffs cada vez más gordos para compensar lo que el receptor no
sabe, es señal de que ese trabajo pertenecía a un solo agent.

### Comparativa rápida

| Situación | Herramienta correcta |
|---|---|
| "Analiza estos 3 aspectos y dame un reporte" | Subagents (Tema 7) |
| "Revisa este PR desde 4 ángulos independientes" | Agent Team |
| "Migra 200 archivos al nuevo API" | Agent Team + worktrees |
| "Arregla este bug" | Ninguno — trabajo directo |
| "Nunca permitas commit sin tests" | Hook (Tema 4) |

---

## Conexión con Ejercicios Anteriores

```
┌─────────────────────────────────────────────────────────┐
│              REGLA DE ORO: ¿QUÉ USAR?                 │
├─────────────────────┬──────────────────────────────────┤
│ SKILL               │ Cosas que el agente DEBE SABER   │
│ HOOK                │ Cosas que SIEMPRE SUCEDEN        │
│ SUBAGENT ← Tema 7   │ Cosas que SE DELEGAN            │
│ AGENT TEAM ← ESTE   │ Colaboración entre especialistas │
│ MCP                 │ INTEGRACIÓN con servicios ext.  │
│ CLAUDE.md           │ Memoria + contexto del proyecto │
└─────────────────────┴──────────────────────────────────┘
```

- **Tema 7 (Subagents):** un Team son subagents especializados encadenados en etapas
- **Tema 6 (Modelos):** Quality-checker usa Haiku (rápido, muchas validaciones)
- **Tema 4-5 (Hooks):** Hooks aplican a cada agent del team — y son el único mecanismo con
  bloqueo **garantizado** (ver la nota sobre `authority` en el Paso 4)

## Checklist de Finalización

### Archivos Creados
- [ ] `.claude/agents/extractor.md` - Agent que extrae datos
- [ ] `.claude/agents/transformer.md` - Agent que transforma datos
- [ ] `.claude/agents/loader.md` - Agent que carga datos
- [ ] `.claude/agents/quality-checker.md` - Agent que valida calidad

### Funcionalidad
- [ ] Extractor extrae y devuelve su payload `START_TRANSFORM`
- [ ] Transformer consume ese payload y devuelve `START_LOAD`
- [ ] Loader carga a destino y devuelve `VERIFY_LOAD`
- [ ] Quality-checker emite veredicto en cada etapa
- [ ] Un veredicto `BLOCKED` detiene el pipeline

### Comunicación
- [ ] Cada agent devuelve su payload JSON en el resultado final
- [ ] El skill coordinador releva cada payload a la etapa siguiente
- [ ] `teammates:` documentado en el frontmatter de cada agent
- [ ] Mensajes incluyen contexto suficiente para el siguiente agent
- [ ] Handoff protocol implementado (opcional — ver Paso 5)

### Comprensión Conceptual
- [ ] Sé que `message` es un string, no un objeto (hay que serializar)
- [ ] Distingo notificación de handoff, y sé cuándo usar cada uno
- [ ] Entiendo que `authority:` y `teammates:` son convención, no enforcement
- [ ] Sé que `tools:` es la única autoridad real del frontmatter
- [ ] Puedo nombrar 2 casos de desarrollo donde un team gana, y 2 donde no
- [ ] Distingo definición de agent (`.md`, se ve con `/agents`) de instancia viva (`ListAgents`)
- [ ] Sé que un agent no espera mensajes: ejecuta su prompt y termina (pero queda reanudable)
- [ ] Sé que el `agentId`, no el nombre del type, es la dirección de un subagent
- [ ] Sé dónde vive el peer-to-peer real: entre sesiones, no entre subagents hermanos

### Prueba End-to-End
- [ ] Datos de muestra generados con `./generar-datos-muestra.sh`
- [ ] Skill run-pipeline creado
- [ ] Corrí `/run-pipeline` y el pipeline completó (extract → transform → load → validate)
- [ ] Conteos verificados en disco: extraídas ≥ transformadas == cargadas
- [ ] Errores son capturados y reportados
- [ ] Provoqué un BLOCK subiendo el rango de filas y vi el pipeline detenerse

## Recursos Adicionales

- [Agent Teams](https://docs.anthropic.com/claude-code/teams)
- [SendMessage API](https://docs.anthropic.com/claude-code/send-message)

## Tip Avanzado

Implementa **dead letter queues** para los payloads que nadie puede procesar. Es el
complemento natural de la regla "encolado ≠ entregado": un mensaje que se pierde en silencio
es un pipeline que miente sobre su estado.

```markdown
## Error Handling

Si un payload no puede ser procesado después de 3 intentos, no lo descartes:
regístralo para revisión humana.

    {
      "action": "DEAD_LETTER",
      "original_payload": { },
      "error": "Formato de fecha no reconocido tras 3 intentos",
      "attempts": 3,
      "stage": "transformation"
    }

El coordinador escribe estos registros en `output/dead_letters.jsonl` y avisa al
operador humano al terminar el pipeline.
```
