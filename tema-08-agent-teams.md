# Agent Teams y Comunicación Peer-to-Peer

**Ejercicio 8 - 20 minutos**

---

## Objetivo

Configurar equipos de agents que colaboran entre sí mediante comunicación peer-to-peer, compartiendo resultados y coordinando trabajo complejo.

## Contexto

Mientras los subagents del Tema 7 son "ejecutores" que reportan a un orquestador, los Agent Teams son "colaboradores" que se comunican entre sí. Esto permite arquitecturas más flexibles donde un agent puede solicitar ayuda de otro sin pasar por el agente principal.

### Diferencia Clave
- **Tema 7 (Subagents):** Todo flujo pasa por el agente principal como orquestador
- **Tema 8 (Agent Teams):** Los agents se comunican directamente entre sí

## Conceptos Clave

- **Agent Team:** Conjunto de agents que pueden comunicarse directamente
- **SendMessage:** Herramienta para enviar mensajes entre agents
- **Peer-to-Peer:** Comunicación directa sin orquestador central
- **Handoff:** Transferencia de tarea de un agent a otro
- **ListAgents:** Descubrir agents disponibles en el team

---

## Nota Previa: La Sintaxis Real de `SendMessage`

Antes de escribir el primer agent, aclaremos la firma real de la herramienta:

```json
{"to": "transformer", "summary": "resumen corto", "message": "texto plano"}
```

**`message` es un string, no un objeto.** Los ejemplos de este tema muestran objetos JSON
porque hacen visible el *protocolo* — qué campos viajan y cuáles son obligatorios. Pero al
ejecutarlos hay que serializar:

```javascript
SendMessage({
  to: "transformer",
  summary: "1000 rows extraidos, listos para transformar",
  message: JSON.stringify({
    action: "START_TRANSFORM",
    data_file: "/tmp/extracted_data.csv",
    row_count: 1000
  })
})
```

| Campo | Tipo | Para qué sirve |
|---|---|---|
| `to` | string | Nombre del agent destino (o `"main"` para la conversación principal) |
| `message` | string | El contenido: JSON serializado, o prosa |
| `summary` | string | 5-10 palabras; es el preview de una línea que ve el usuario en la UI |

> **En la práctica, prosa estructurada funciona igual de bien que JSON** — el receptor es un
> modelo, no un parser. Usamos JSON aquí porque impone disciplina y hace evidente qué
> información no se puede omitir. Elige según tu caso.

---

## Paso 0: Crear Directorio de Agents (Si no existe)

```bash
# Crear estructura de directorios
mkdir -p .claude/agents
mkdir -p .claude/skills
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
Tu tarea es extraer datos de fuentes y prepararlos para transformación.

## Proceso

1. Recibir la configuración inicial (via SendMessage)
2. Conectar a la fuente de datos
3. Extraer y validar básicamente los datos
4. Guardar datos en archivo temporal
5. **Notificar a transformer** con ruta del archivo

## Cómo Comunicarte

Cuando termines extracción EXITOSA:

\`\`\`javascript
SendMessage({
  to: "transformer",
  message: {
    "action": "START_TRANSFORM",
    "data_file": "/tmp/extracted_data.csv",
    "row_count": 1000,
    "columns": ["id", "name", "email"]
  }
})
\`\`\`

Si detectas problemas, notifica a quality-checker:

\`\`\`javascript
SendMessage({
  to: "quality-checker",
  message: {
    "action": "VALIDATE",
    "stage": "extraction",
    "issues": ["schema_mismatch", "null_values_found"],
    "severity": "warning"
  }
})
\`\`\`

## Flujo Esperado
- Esperar mensaje de inicio
- Ejecutar extracción
- Enviar datos a transformer
- Mantener copia de backup
```
```

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
Aplicar transformaciones y validaciones a datos extraídos.

## Proceso de Transformación

1. Escuchar mensaje de **extractor**
2. Leer datos del archivo proporcionado
3. Aplicar limpieza y transformaciones
4. Validar resultado
5. **Notificar a loader** con datos transformados

## Cómo Responder a Extractor

Cuando recibas mensaje de extractor:

\`\`\`javascript
// Escucharás algo como:
{
  "action": "START_TRANSFORM",
  "data_file": "/tmp/extracted_data.csv",
  "row_count": 1000
}

// Después de transformar, envía:
SendMessage({
  to: "loader",
  message: {
    "action": "START_LOAD",
    "data_file": "/tmp/transformed_data.csv",
    "row_count": 950,
    "transformations_applied": [
      "removed_duplicates",
      "normalized_dates",
      "filled_missing_values"
    ]
  }
})
\`\`\`

## Validación Cruzada

Si necesitas clarificación o encuentras anomalías:

\`\`\`javascript
SendMessage({
  to: "extractor",
  message: {
    "action": "CLARIFY",
    "issue": "column_missing",
    "details": "Expected 'timestamp' column not found"
  }
})
\`\`\`
```
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
  - SendMessage
teammates:
  - transformer
  - extractor
  - quality-checker
---

# Loader Agent

## Responsabilidad
Cargar datos transformados a su destino final.

## Proceso de Carga

1. Escuchar mensaje de **transformer**
2. Validar integridad del archivo
3. Cargar a destino (archivo, BD, warehouse, etc.)
4. Verificar integridad de carga
5. **Notificar a quality-checker** sobre completitud

## Manejo de Mensajes del Transformer

Recibirás:

\`\`\`javascript
{
  "action": "START_LOAD",
  "data_file": "/tmp/transformed_data.csv",
  "row_count": 950
}

// Después de cargar exitosamente:
SendMessage({
  to: "quality-checker",
  message: {
    "action": "VERIFY_LOAD",
    "destination": "analytics_table",
    "rows_loaded": 950,
    "load_timestamp": "2024-08-23T10:30:00Z",
    "status": "SUCCESS"
  }
})
\`\`\`

## En Caso de Error

\`\`\`javascript
SendMessage({
  to: "quality-checker",
  message: {
    "action": "LOAD_FAILED",
    "error": "Connection refused to database",
    "rows_attempted": 950,
    "rows_loaded": 0
  }
})
\`\`\`
```
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
Supervisar calidad y bloquear si hay problemas críticos.

## Qué Validar

### Fase de Extracción
- ✓ Row count dentro de rangos esperados (ej: 100-10000 rows)
- ✓ Todas las columnas esperadas presentes
- ✓ No valores NULL en columnas clave
- ✓ Tipos de datos coinciden

### Fase de Transformación
- ✓ Ninguna pérdida de datos (rows_in ≈ rows_out)
- ✓ Duplicados removidos correctamente
- ✓ Fechas normalizadas correctamente
- ✓ Valores esperados en rangos válidos

### Fase de Carga
- ✓ Integridad referencial mantenida
- ✓ Conteos coinciden con entrada
- ✓ Timestamps de carga correctos
- ✓ No duplicados en destino

## Cómo Actuar

Cuando recibas validaciones de otros agents:

**Si pasa validación:**

\`\`\`javascript
// Solo registra - el flujo continúa
SendMessage({
  to: "extractor",  // o el agent que notificó
  message: {
    "action": "VALIDATION_PASSED",
    "stage": "extraction",
    "checks_passed": 4,
    "timestamp": "2024-08-23T10:15:00Z"
  }
})
\`\`\`

**Si detectas problema CRÍTICO:**

\`\`\`javascript
// BLOQUEA el flujo
SendMessage({
  to: "transformer",  // bloquea el siguiente agent
  message: {
    "action": "BLOCK",
    "reason": "Critical data quality issue",
    "issue": "50% NULL values in ID column",
    "recommendation": "Extractor debe reintentar with schema validation",
    "severity": "CRITICAL"
  }
})
\`\`\`

El agent bloqueado debe parar y reportar al usuario.

## Escalación

Si un problema ocurre 3+ veces:

\`\`\`javascript
SendMessage({
  to: "extractor",
  message: {
    "action": "ESCALATE",
    "reason": "Pattern detected - repeated validation failures",
    "failed_attempts": 3,
    "recommendation": "Manual review needed - possible source data corruption"
  }
})
\`\`\`
```
```

### Sobre `authority: can-block` — Qué es Real y Qué es Convención

Detente aquí un momento, porque este campo enseña algo importante sobre cómo funcionan
realmente los agents.

**El frontmatter que Claude Code interpreta es:** `name`, `description`, `tools`, `model` y
`teammates`. Cualquier otra clave —`authority` incluida— se ignora silenciosamente al cargar
el agent.

> **Matiz importante sobre `teammates` (comprobado en el Paso 8):** aunque se carga, **no
> crea rutas de mensajería**. Un `SendMessage` de un agent a otro listado en sus `teammates`
> falla con `"no reachable"` si ambos son subagents hermanos de la misma sesión. Para la
> mensajería, `teammates:` es tan convencional como `authority:`.

Compruébalo tú mismo: pídele a Claude que liste los agents disponibles. Verás
`quality-checker` con su description, sus tools y su model. De `authority` no queda rastro.

**Entonces, ¿por qué funciona?** Porque el agent lee su propio prompt. `authority: can-block`
es una **convención semántica**: le comunica al modelo "tú tienes potestad de detener esto".
El bloqueo es **cooperativo** — ocurre porque el modelo coopera, no porque el runtime lo
imponga.

Eso no lo hace inútil: documentar roles en el frontmatter es buena práctica y el modelo
efectivamente los respeta. Pero hay que saber qué garantía tienes. Otros valores que puedes
documentar con la misma lógica:

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
ni código ejecutable suelto.** Es un *formato de mensaje* que documentas **dentro del body de
un agent `.md`**, en su sección "Cómo Comunicarte". Es la misma llamada `SendMessage` de los
Pasos 1-4, solo que con un payload más rico.

**Es opcional.** El pipeline de este ejercicio funciona sin él. Pero resuelve un problema
concreto que conviene entender.

### Notificación vs. Handoff

| | Notificación (Pasos 1-4) | Handoff (este paso) |
|---|---|---|
| **Payload** | `{data_file, row_count}` | + qué se hizo, qué falta, restricciones, artifacts |
| **Supuesto** | El receptor ya sabe su trabajo | El receptor **no tiene tu contexto** |
| **Tarea** | Predefinida y fija | Abierta ("limpia esto, tú decides cómo") |
| **Emisor** | Sigue vivo, puede recibir respuesta | **Termina** tras enviar |

La razón de fondo: **cada agent corre en su propia ventana de contexto**. El `transformer` no
ve *nada* de lo que hizo el `extractor` — ni los archivos que leyó, ni las decisiones que
tomó, ni los errores que sorteó por el camino.

Si la tarea del receptor está fija de antemano, tres campos bastan. Si el receptor tiene que
**decidir** algo, necesita el contexto completo o improvisará a ciegas.

**Formato de Handoff:**

```javascript
SendMessage({
  to: "next_agent",
  message: {
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
})
```

**Después del handoff, el agent que delegó debe finalizar su tarea.** No se queda esperando
respuesta: transfirió la responsabilidad completa.

### Dónde ponerlo en TU ejercicio

En `.claude/agents/extractor.md`, como **alternativa** al `START_TRANSFORM` estándar. Añade
esta sección al body del agent:

```markdown
## Handoff Completo (cuando la transformación no es rutinaria)

Normalmente envías START_TRANSFORM y sigues disponible. Pero si detectas que los datos
requieren limpieza NO estándar (schema inesperado, formatos mixtos, reglas de negocio
ambiguas), transfiere la tarea completa y termina:

SendMessage({
  to: "transformer",
  summary: "Handoff: datos requieren limpieza no estandar",
  message: JSON.stringify({
    action: "HANDOFF",
    task_description: "Limpiar ventas_2024.csv - formatos de fecha mixtos",
    context: {
      what_was_done: ["Extraido de PostgreSQL", "Schema validado parcialmente"],
      what_remains: ["Normalizar 3 formatos de fecha distintos", "Cargar a warehouse"],
      important_constraints: ["Los customer_id son datos sensibles - no loguear"]
    },
    artifacts: [{ path: "/tmp/extracted_data.csv", description: "1000 rows crudos" }]
  })
})

Después de enviar el HANDOFF, tu tarea termina. No esperes respuesta.
```

> **Regla para decidir:** si puedes describir el trabajo del receptor en una sola línea de tu
> propio prompt, usa una notificación. Si necesitas explicarle *por qué* y *bajo qué
> restricciones*, usa un handoff.

---

## Paso 6: Cómo Iniciar el Team - ListAgents

**Herramienta disponible:** `ListAgents`

Para descubrir todos los agents en tu team:

```bash
# Desde tu aplicación/skill, usa:
await ListAgents()

# Esto retorna:
// {
//   "agents": [
//     { "name": "extractor", "status": "ready" },
//     { "name": "transformer", "status": "ready" },
//     { "name": "loader", "status": "ready" },
//     { "name": "quality-checker", "status": "ready" }
//   ]
// }
```

---

## Paso 7: Ejecutar el Team - Ejemplo Práctico

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

Este skill inicia y coordina el pipeline de datos.

## Flujo Completo

### 1. Spawn de Agents
Primero, inicia todos los agents del team usando el Agent tool:

\`\`\`javascript
// Iniciar los 4 agents del team.
// OJO: el parametro es `subagent_type`, no `agentType`.
// Lanzalos en UN SOLO mensaje (varias tool calls en paralelo).
const extractor = await Agent({
  description: "Extractor agent for data pipeline",
  subagent_type: "extractor"
})

const transformer = await Agent({
  description: "Transformer agent for data pipeline",
  subagent_type: "transformer"
})

const loader = await Agent({
  description: "Loader agent for data pipeline",
  subagent_type: "loader"
})

const qualityChecker = await Agent({
  description: "Quality checker for data pipeline",
  subagent_type: "quality-checker"
})
\`\`\`

### 2. Iniciar Extracción
Envía el primer mensaje al extractor:

\`\`\`javascript
SendMessage({
  to: "extractor",
  summary: "START: extraer ventas_2024.csv",
  message: JSON.stringify({
    action: "START",
    config: {
      source: "data/ventas_2024.csv",
      type: "csv"
    },
    instructions: "Extract all rows and pass to transformer"
  })
})
\`\`\`

### 3. Monitorear Progreso
El flujo será:
- extractor → (SendMessage) → transformer
- transformer → (SendMessage) → loader  
- loader → (SendMessage) → quality-checker
- quality-checker → reporta resultado

### 4. Manejo de Errores
Si quality-checker bloquea:

\`\`\`javascript
SendMessage({
  to: "extractor",
  message: {
    "action": "RETRY",
    "reason": "Quality check failed, retrying extraction",
    "attempt": 2
  }
})
\`\`\`
```
```

---

## Paso 8: Ejecutar el Flujo Final — y Qué Pasa de Verdad

Ya tienes los 4 agents y el skill. **¿Cómo lo corres?**

```
/run-pipeline
```

Eso es todo. Y aquí conviene detenerse, porque el bloque ```javascript``` del SKILL.md
**no es código que se ejecute**. Un skill son *instrucciones para el agente principal*: Claude
lee el SKILL.md y hace las llamadas reales a `Agent(...)` y `SendMessage(...)`. Nadie
interpreta ese JavaScript.

### Antes de correr: prepara los datos

```bash
./generar-datos-muestra.sh .        # crea data/ventas_2024.csv y output/
```

### Dos erratas del Paso 7 que hay que corregir para que funcione

| En el ejemplo | Correcto |
|---|---|
| `agentType: "extractor"` | `subagent_type: "extractor"` |
| `message: { ... }` | `message: JSON.stringify({ ... })` |

La segunda contradice el propio Paso 7 — la Nota Previa ya avisó que `message` es un string.

---

### Lo que descubres al correrlo (y el tema debe admitir)

Este ejercicio se ejecutó de verdad. El resultado importa más que el pipeline:

**1. `ListAgents` vacío no es un error.** Antes de lanzar nada:

```
No reachable agents
```

Los `.md` de `.claude/agents/` son **definiciones** (agent *types*), no procesos. `ListAgents`
lista **instancias vivas**. Para ver las definiciones cargadas: `/agents`.

**2. Un agent NO espera mensajes.** No existe primitiva de espera. Al lanzar los 4 en
paralelo, tres terminaron en ~12 segundos sin hacer nada:

```
transformer      → "no he recibido START_TRANSFORM"   → termina
loader           → "no he recibido START_LOAD"        → termina
quality-checker  → "aguardando mensajes"              → termina
extractor        → (62s: leer, contar, copiar)        → intenta notificar...
```

Cuando el extractor fue a notificar, ya no quedaba nadie. **"Escuchar mensaje de extractor"
—Pasos 2 y 3— no es algo que un agent pueda hacer.**

**3. Los teammates no son alcanzables entre sí.** El extractor obtuvo:

```
SendMessage a "transformer"      → No agent named 'transformer' is reachable
SendMessage a "quality-checker"  → No agent named 'quality-checker' is reachable
```

Y esto es lo importante: **`teammates:` en el frontmatter no crea rutas de mensajería.** Cae
en la misma categoría que `authority: can-block` — convención documental. Los 4 agents son
*hermanos*, hijos del agente principal, no peers entre sí.

> Corrección al Paso 4: ese apartado dice que Claude Code interpreta `teammates`. Para la
> mensajería entre subagents hermanos, **no lo hace**. La única autoridad real del
> frontmatter sigue siendo `tools:`.

**4. El nombre del type no es una dirección.** Incluso desde el agente principal:

```
SendMessage({to: "transformer", ...})       → No agent named 'transformer' is reachable
SendMessage({to: "a18048adb026a856f", ...}) → Resuming agent a18048a   ✓
```

Hay que usar el **`agentId` de la instancia**, que devuelve el spawn. Y nota `Resuming`: un
agent terminado **sigue siendo reanudable** desde su transcript. Eso es lo que hace viable el
pipeline.

**5. Encolado ≠ entregado.** Un mensaje a un agent *vivo* responde
`Message queued for delivery at its next tool round`. Si el agent termina su turno antes de
ese round, **el mensaje no se procesa**: nuestro quality-checker validó dos etapas y terminó
diciendo "awaiting VERIFY_LOAD" con el mensaje encolado sin consumir. Hubo que reenviarlo.
Este es exactamente el agujero que justifica el patrón *dead letter queue* del Tip Avanzado.

---

### El patrón que sí funciona: relevo por el padre

Los agents no se hablan entre sí; **el agente principal releva cada payload** al siguiente,
por `agentId`:

```
extractor  ──payload──►  [principal]  ──SendMessage(agentId)──►  transformer
transformer ─payload──►  [principal]  ──SendMessage(agentId)──►  loader
loader ─────payload──►  [principal]  ──SendMessage(agentId)──►  quality-checker
```

Para que el relevo sea posible, cada agent debe **devolver en su resultado final el payload
JSON** que le habría enviado al siguiente, en vez de intentar un `SendMessage` que fallará.
Añade esto al body de cada agent:

```markdown
## Notificación

Tus teammates NO son alcanzables desde tu contexto (`SendMessage` a ellos falla con
"no reachable" — son agents hermanos, no tus subagents). NO intentes enviarles mensajes.
Devuelve en tu resultado final el payload JSON destinado al siguiente agent; el coordinador
lo releva.
```

**Sí, esto es hub-and-spoke — el Tema 7.** Reconocerlo es la lección: el peer-to-peer entre
subagents hermanos no está disponible por esta vía. `SendMessage` entre peers **sí** funciona
entre *sesiones* de Claude Code (ver `ListAgents` cross-session), no entre subagents de una
misma sesión.

---

### Resultado esperado end-to-end

```
etapa            filas   artefacto
─────────────────────────────────────────────────────────
extracción         12    /tmp/extracted_data.csv
transformación     11    /tmp/transformed_data.csv     (descarta 1: cantidad vacía)
carga              11    output/ventas_cargadas.csv    (+ columna total)
```

La fila descartada es el valor faltante sembrado a propósito en `ventas_2024.csv`. Fuerza una
decisión real del quality-checker: su regla dice *"ninguna pérdida de datos"*, pero el dato es
irrecuperable. Nuestro quality-checker dio **PASSED** con la justificación de que `cantidad`
es necesaria para GMV y no se puede imputar sin arbitrariedad — y dejó nota de que producción
necesita una política explícita de imputación vs. descarte. Ese razonamiento *es* el
entregable del ejercicio, no el CSV.

### Cómo comprobarlo — 4 niveles

```bash
# 1. Definiciones cargadas        → /agents      (los 4, con model y tools)
# 2. Instancias vivas             → ListAgents   (running / completed)
# 3. Artefactos y conteos
wc -l /tmp/extracted_data.csv /tmp/transformed_data.csv output/ventas_cargadas.csv
# 4. Veredicto del quality-checker: PASSED o BLOCK por cada etapa
```

Para el nivel 3, que los conteos cuadren: `extraídas ≥ transformadas == cargadas`.

### Variante: ver un BLOCK de verdad

El quality-checker exige "row count entre 100-10000" y el dataset tiene 12 filas. Tal cual,
**bloquea** — y eso comprueba el ítem "Bloqueos de quality-checker detienen el pipeline". Para
el camino feliz, baja el rango a `5-10000` en `quality-checker.md`.

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
┌─────────────────────────────────────────────────────────┐
│                    AGENT TEAM                          │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   ┌───────────┐    data     ┌─────────────┐            │
│   │ EXTRACTOR │ ─────────►  │ TRANSFORMER │            │
│   └─────┬─────┘             └──────┬──────┘            │
│         │                          │                   │
│         │ validate                 │ validate          │
│         ▼                          ▼                   │
│   ┌─────────────────────────────────────┐              │
│   │         QUALITY CHECKER             │              │
│   │    (puede bloquear cualquiera)      │              │
│   └─────────────────────────────────────┘              │
│         ▲                          ▲                   │
│         │ validate                 │                   │
│         │                          │ data              │
│   ┌─────┴─────┐             ┌──────┴──────┐            │
│   │  LOADER   │ ◄───────────│ TRANSFORMER │            │
│   └───────────┘             └─────────────┘            │
│                                                         │
└─────────────────────────────────────────────────────────┘
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
correlacionando hallazgos vía `SendMessage`. Ningún contexto único aguanta los logs de cinco
servicios a la vez.

**5. Pipeline de datos real (nuestro ejercicio, a escala)**
Con 1000 archivos, el extractor procesa el archivo N+1 mientras el transformer aún trabaja en
el N. Con subagents centralizados (Tema 7) esperarías cada paso.

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

- **Tema 7 (Subagents):** Teams son subagents que se comunican entre sí
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
- [ ] Extractor puede recibir y procesar mensaje START
- [ ] Transformer recibe datos de extractor y envía a loader
- [ ] Loader recibe datos transformados y notifica resultado
- [ ] Quality-checker monitorea todas las etapas
- [ ] Quality-checker puede BLOQUEAR si hay problemas

### Comunicación
- [ ] `teammates:` documentado en el frontmatter de cada agent
- [ ] Comprobé que `SendMessage` entre agents hermanos falla con "no reachable"
- [ ] Cada agent devuelve su payload JSON en el resultado final, para que el principal releve
- [ ] Mensajes incluyen contexto suficiente para el siguiente agent
- [ ] Handoff protocol implementado (opcional — ver Paso 5)

### Comprensión Conceptual
- [ ] Sé que `message` es un string, no un objeto (hay que serializar)
- [ ] Distingo notificación de handoff, y sé cuándo usar cada uno
- [ ] Entiendo que `authority:` es convención cooperativa, no enforcement
- [ ] Sé que `tools:` es la única autoridad real del frontmatter
- [ ] Puedo nombrar 2 casos de desarrollo donde un team gana, y 2 donde no
- [ ] Sé que `teammates:` tampoco crea rutas de mensajería — es convención, como `authority:`
- [ ] Distingo definición de agent (`.md`, se ve con `/agents`) de instancia viva (`ListAgents`)
- [ ] Sé que un agent no espera mensajes: ejecuta su prompt y termina (pero queda reanudable)
- [ ] Sé que el `agentId`, no el nombre del type, es la dirección de un subagent

### Prueba End-to-End
- [ ] Datos de muestra generados con `./generar-datos-muestra.sh`
- [ ] Skill run-pipeline creado, con `subagent_type` y `JSON.stringify` corregidos
- [ ] Corrí `/run-pipeline` y el pipeline completó (extract → transform → load → validate)
- [ ] Conteos verificados en disco: extraídas ≥ transformadas == cargadas
- [ ] Errores son capturados y reportados
- [ ] Vi un BLOCK del quality-checker detener el pipeline (rango de filas sin ajustar)

## Recursos Adicionales

- [Agent Teams](https://docs.anthropic.com/claude-code/teams)
- [SendMessage API](https://docs.anthropic.com/claude-code/send-message)

## Tip Avanzado

Implementa **dead letter queues** para mensajes que no pueden ser procesados:

```markdown
## Error Handling

Si un mensaje no puede ser procesado después de 3 intentos:

\`\`\`
SendMessage(
  to: "dead-letter-handler",
  message: {
    "original_message": {...},
    "error": "...",
    "attempts": 3,
    "timestamp": "..."
  }
)
\`\`\`

El dead-letter-handler alertará al operador humano.
```
