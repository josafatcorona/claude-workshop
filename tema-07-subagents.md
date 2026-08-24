# Subagents y Aislamiento de Contexto

**Ejercicio 7 - 20 minutos**

---

## Objetivo

Implementar subagents que ejecutan tareas especializadas en paralelo con contexto aislado, maximizando eficiencia y evitando contaminación de contexto.

## Contexto

Cuando una tarea es demasiado grande o compleja, dividirla entre subagents permite procesamiento paralelo y especializado. Cada subagent tiene su propio contexto, evitando que información irrelevante consuma tokens. Es como tener un equipo de especialistas en lugar de un generalista sobrecargado.

## Conceptos Clave

- **Subagent:** Instancia de Claude con contexto independiente, especializada en una tarea
- **Aislamiento de Contexto:** Cada subagent solo ve la información relevante a su tarea
- **Orquestación:** El agente principal coordina subagents y consolida resultados
- **Fork:** Subagent que hereda el contexto completo del padre (útil para research)

---

## Paso 1: Estructura de un Subagent

Crea definiciones de agents en `.claude/agents/`:

```bash
mkdir -p .claude/agents
touch .claude/agents/data-analyzer.md
```

```markdown
<!-- .claude/agents/data-analyzer.md -->
---
name: data-analyzer
description: Analiza datasets y genera insights estadísticos
model: claude-sonnet-5
tools:
  - Bash
  - Read
  - Write
---

# Data Analyzer Agent

Eres un agente especializado en análisis de datos.

## Capacidades
- Análisis estadístico descriptivo
- Detección de outliers
- Identificación de patrones
- Generación de visualizaciones

## Restricciones
- Solo operas sobre archivos en data/ y output/
- No modificas código fuente
- Reportas en formato JSON estructurado

## Output Format
Siempre responde con JSON:
\`\`\`json
{
  "summary": "descripción breve",
  "metrics": {...},
  "insights": [...],
  "recommendations": [...]
}
\`\`\`
```

---

## Paso 2: Crear Agent de Validación

```bash
touch .claude/agents/validator.md
```

```markdown
<!-- .claude/agents/validator.md -->
---
name: validator
description: Valida datos y código contra reglas del proyecto
model: claude-haiku-4-5-20251001
tools:
  - Bash
  - Read
---

# Validator Agent

Eres un agente de validación rápida.

## Funciones
1. Validar estructura de DataFrames
2. Verificar tipos de datos
3. Detectar valores inválidos
4. Verificar convenciones de código

## Output
\`\`\`json
{
  "valid": true/false,
  "errors": [...],
  "warnings": [...]
}
\`\`\`
```

---

## Paso 3: Crear Agent de Documentación

```bash
touch .claude/agents/documenter.md
```

```markdown
<!-- .claude/agents/documenter.md -->
---
name: documenter
description: Genera documentación técnica y reportes
model: claude-sonnet-5
tools:
  - Read
  - Write
---

# Documenter Agent

Eres un agente especializado en documentación.

## Capacidades
- Generar docstrings
- Crear README files
- Documentar APIs
- Escribir reportes de análisis

## Estilo
- Conciso pero completo
- Ejemplos prácticos
- Formato Markdown
```

---

## Paso 4: Invocar Subagents desde el Agente Principal

### 4a. Invocación Interactiva

En tu sesión principal de Claude Code, simplemente describe lo que necesitas:

```
Necesito analizar el archivo data/ventas_2024.csv en paralelo:

1. Usa el agent "data-analyzer" para análisis estadístico
2. Usa el agent "validator" para validar la estructura
3. Después, usa "documenter" para crear el reporte
```

Claude Code detecta automáticamente los agents definidos en `.claude/agents/` y los ejecuta.

### 4b. Programáticamente: Crear un Skill de Orquestación

Para automatizar la orquestación, crea un Skill que coordine múltiples subagents:

```bash
mkdir -p .claude/skills/analyze-with-agents
touch .claude/skills/analyze-with-agents/SKILL.md
```

**Contenido de .claude/skills/analyze-with-agents/SKILL.md:**

```markdown
---
name: analyze-with-agents
description: Análisis completo de CSV con subagents paralelos y consolidación
arguments:
  - name: file
    description: Ruta al archivo CSV (ej: data/ventas_2024.csv)
    required: true
---

# Skill: Análisis Completo con Subagents

Este skill orquesta tres subagents especializados que ejecutan en paralelo.

## Fase 1: Spawn Paralelo (Ejecución Simultánea)

Lanza 3 agentes sin esperar a que terminen:

### Agent 1: Data Analyzer
- **Nombre personalizado:** "data-analyzer"
- **Prompt:** "Analiza {{file}} y proporciona: estadísticas descriptivas, distribuciones, top productos, GMV total. Responde en JSON."
- **Modelo:** claude-sonnet-5 (análisis complejo)
- **Timeout:** 60s

### Agent 2: Validator  
- **Nombre personalizado:** "validator"
- **Prompt:** "Valida {{file}}: estructura, tipos de datos, valores nulos, integridad. Responde en JSON."
- **Modelo:** claude-haiku-4-5-20251001 (validación rápida)
- **Timeout:** 30s

### Agent 3: Documenter
- **Nombre personalizado:** "documenter"
- **Prompt:** "Prepárate para crear un reporte ejecutivo de {{file}}. Listo para recibir resultados."
- **Modelo:** claude-sonnet-5 (síntesis compleja)
- **Timeout:** 45s

## Fase 2: Consolidación (Espera + Síntesis)

Una vez que los 3 agents terminen, consolida resultados:

1. **Comparar outputs:** 
   - Si el validator reporta inconsistencias, el analyzer debe ignorar esas filas
   - El documenter usa insights del analyzer + issues del validator

2. **Síntesis:**
   - Crear resumen ejecutivo
   - Listar recomendaciones

## Fase 3: Output Final

```json
{
  "status": "success",
  "analyzed_file": "{{file}}",
  "validation": {...},
  "statistics": {...},
  "report": "output/report_{{file}}.md"
}
```
```

**Usar el skill:**

```bash
/analyze-with-agents file=data/ventas_2024.csv
```

### 4c. Patrón Maestro: Orquestación Sequential vs Paralela

**Sequential (Esperar cada resultado):**
```
1. Validator ejecuta
2. Si válido → Analyzer ejecuta
3. Analyzer termina → Documenter ejecuta
⏱ Tiempo: suma de las 3
```

**Paralela (Ejecutar simultáneamente):**
```
1. Validator, Analyzer, Documenter inician al mismo tiempo
2. Esperar a que TODOS terminen
3. Consolidar resultados
⏱ Tiempo: máximo de los 3
```

En Claude Code, usa **paralela** por defecto:
- Más rápido (wall-clock time = max(T1, T2, T3), no T1+T2+T3)
- Si el validator es lento, no bloquea al analyzer
- Permite que el documenter prepare estructura mientras los otros trabajan

### 4d. Consolidación Manual vs Automática

**Manual (el skill coordina):**
```markdown
## Paso A: Spawn agents en paralelo
## Paso B: Esperar resultados
## Paso C: Combinar outputs
## Paso D: Guardar reporte
```

**Automática (los agents se comunican):**
Requiere agent teams (Tema 8) donde validator → analyzer → documenter se coordina internamente.

Para Tema 7, usa **consolidación manual**.

---

## Paso 5: Fork vs Subagent Nuevo

**Fork (hereda contexto):**
```
Uso un fork cuando necesito que el agente sepa todo lo que 
hemos discutido hasta ahora, pero quiero que explore sin 
contaminar mi contexto principal.
```

**Subagent nuevo (contexto limpio):**
```
Uso un subagent nuevo cuando la tarea es independiente y 
no necesita saber nada de nuestra conversación actual.
```

**Tabla de decisión:**

```
┌─────────────────────────────────────────────────────────┐
│              FORK vs SUBAGENT NUEVO                    │
├────────────────────┬───────────────────────────────────┤
│ FORK               │ SUBAGENT NUEVO                    │
├────────────────────┼───────────────────────────────────┤
│ Research abierto   │ Tarea específica definida        │
│ "Investiga X"      │ "Calcula Y en archivo Z"         │
│ Necesita contexto  │ Contexto autosuficiente          │
│ Exploratorio       │ Determinístico                   │
│ Un solo agente     │ Múltiples en paralelo            │
└────────────────────┴───────────────────────────────────┘
```

---

## Paso 6: Patrón de Orquestación Completo

```python
# orchestration_pattern.py (pseudocódigo conceptual)

async def analyze_with_subagents(file_path: str):
    """
    Orquesta múltiples subagents para análisis paralelo.
    """
    
    # Fase 1: Validación (gate)
    validation = await spawn_agent(
        type="validator",
        task=f"Valida {file_path}",
        model="haiku"  # Rápido y barato
    )
    
    if not validation['valid']:
        return {"error": "Validación fallida", "details": validation['errors']}
    
    # Fase 2: Análisis paralelo
    analysis_tasks = [
        spawn_agent(type="data-analyzer", task=f"Estadísticas de {file_path}"),
        spawn_agent(type="data-analyzer", task=f"Detección de outliers en {file_path}"),
        spawn_agent(type="data-analyzer", task=f"Correlaciones en {file_path}"),
    ]
    
    results = await gather(*analysis_tasks)
    
    # Fase 3: Consolidación y documentación
    report = await spawn_agent(
        type="documenter",
        task=f"Genera reporte consolidando: {results}",
        model="sonnet"  # Necesita síntesis
    )
    
    return report
```

---

## Conexión con Ejercicios Anteriores

```
┌─────────────────────────────────────────────────────────┐
│              REGLA DE ORO: ¿QUÉ USAR?                 │
├─────────────────────┬──────────────────────────────────┤
│ SKILL               │ Cosas que el agente DEBE SABER   │
│ HOOK                │ Cosas que SIEMPRE SUCEDEN        │
│ SUBAGENT ← ESTE     │ Cosas que SE DELEGAN            │
│ MCP                 │ INTEGRACIÓN con servicios ext.  │
│ CLAUDE.md           │ Memoria + contexto del proyecto │
└─────────────────────┴──────────────────────────────────┘
```

- **Tema 3 (Skills):** Un skill puede orquestar múltiples subagents
- **Tema 6 (Modelos):** Cada subagent usa el modelo apropiado a su tarea
- Los subagents heredan permisos del settings.json del proyecto

## Checklist de Finalización

- [ ] Directorio .claude/agents/ creado
- [ ] Agent data-analyzer.md definido
- [ ] Agent validator.md definido
- [ ] Agent documenter.md definido
- [ ] Probado invocar subagents en paralelo
- [ ] Entendida diferencia fork vs subagent nuevo

## Recursos Adicionales

- [Agent Definitions](https://platform.claude.com/docs/en/managed-agents/agent-setup)
- [Parallel Execution](https://code.claude.com/docs/en/agents#run-agents-in-parallel)

## Tip Avanzado

Usa **schemas** para forzar output estructurado de subagents:

```markdown
---
name: structured-analyzer
schema:
  type: object
  properties:
    summary:
      type: string
    metrics:
      type: object
    confidence:
      type: number
      minimum: 0
      maximum: 1
  required: [summary, metrics, confidence]
---
```

Con schema, el subagent **debe** retornar ese formato exacto, facilitando la consolidación automática de resultados.
