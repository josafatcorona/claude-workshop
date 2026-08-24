# Elección de Modelo y Optimización de Tokens

**Ejercicio 6 - 15 minutos**

---

## Objetivo

Aprender a seleccionar el modelo correcto (Opus, Sonnet, Haiku) según el caso de uso y optimizar el consumo de tokens mediante caching, compactación y chunking.

## Contexto

No todas las tareas requieren el modelo más potente. Elegir correctamente entre Opus, Sonnet y Haiku puede reducir costos 10-50x sin perder calidad. Además, técnicas como prompt caching y context compaction maximizan el valor de cada token usado.

## Conceptos Clave

- **Model Tiers:** Opus (máxima capacidad) → Sonnet (balance) → Haiku (velocidad/costo)
- **Prompt Caching:** Reutilizar prefijos de prompts para reducir latencia y costo
- **Context Compaction:** Resumir contexto largo para mantener información crítica
- **Token Budget:** Límite de tokens por request y por sesión

---

## Paso 1: Matriz de Selección de Modelo

```
┌────────────────────────────────────────────────────────────────┐
│                 SELECCIÓN DE MODELO                            │
├─────────────┬──────────┬──────────┬───────────┬───────────────┤
│ TAREA       │ OPUS     │ SONNET   │ HAIKU     │ RECOMENDADO   │
├─────────────┼──────────┼──────────┼───────────┼───────────────┤
│ Arquitectura│ ████████ │ ██████   │ ███       │ OPUS          │
│ Refactoring │ ████████ │ ███████  │ ████      │ SONNET        │
│ Bug fix     │ ███████  │ ████████ │ █████     │ SONNET        │
│ Code review │ ████████ │ ███████  │ █████     │ OPUS/SONNET   │
│ Tests       │ ██████   │ ████████ │ ██████    │ SONNET        │
│ Formatting  │ ████     │ ██████   │ █████████ │ HAIKU         │
│ Docs simple │ █████    │ ███████  │ █████████ │ HAIKU         │
│ Traducción  │ ██████   │ ███████  │ ████████  │ SONNET/HAIKU  │
│ Análisis    │ █████████│ ███████  │ █████     │ OPUS          │
│ SQL queries │ ███████  │ ████████ │ ██████    │ SONNET        │
└─────────────┴──────────┴──────────┴───────────┴───────────────┘
```

**Regla práctica:**
- **Opus:** Decisiones de diseño, análisis complejos, cuando la calidad es crítica
- **Sonnet:** Desarrollo día a día, 80% de las tareas
- **Haiku:** Tareas mecánicas, alto volumen, validaciones simples

---

## Paso 2: Configurar Modelo por Defecto

En `.claude/settings.json`:

```json
{
  "model": {
    "default": "claude-sonnet-5",
    "overrides": {
      "skills": {
        "analyze-csv": "claude-sonnet-5",
        "architecture-review": "claude-opus-5",
        "format-code": "claude-haiku-4-5-20251001"
      },
      "hooks": {
        "validate-*": "claude-haiku-4-5-20251001"
      }
    }
  }
}
```

**⚠️ Recuerda (Tema 2):** esto es solo la clave `model` — agrégala junto a las claves `permissions`, `env` y `hooks` que ya tienes en tu `settings.json`, no reemplaces el archivo.

En CLAUDE.md, indica preferencias:

```markdown
## Preferencias de Modelo

- Para análisis exploratorio: usar Sonnet
- Para revisiones de arquitectura: usar Opus
- Para formateo y linting: usar Haiku
- Para subagents de validación: usar Haiku (alta paralelización)
```

---

## Paso 3: Implementar Prompt Caching

El prompt caching reutiliza prefijos idénticos entre requests.

**Estructura de prompt cacheable:**

```python
# prompt_templates.py

SYSTEM_PREFIX = """
Eres un asistente de análisis de datos especializado.
Tu contexto incluye:
- Stack: Python, pandas, scikit-learn
- Base de datos: PostgreSQL, DuckDB
- Convenciones: PEP 8, type hints obligatorios

Reglas:
1. Siempre validar inputs
2. Usar funciones puras cuando sea posible
3. Documentar assumptions
"""

# Este prefijo se cachea, el sufijo cambia por request
def create_analysis_prompt(data_description: str) -> str:
    return f"{SYSTEM_PREFIX}\n\nAnaliza los siguientes datos:\n{data_description}"
```

**En settings.json:**

```json
{
  "caching": {
    "enabled": true,
    "prefixCaching": true,
    "ttl": 3600
  }
}
```

**Verificación del cache:**
```bash
claude --stats  # Muestra hit rate del cache
```

---

## Paso 4: Context Compaction

Cuando el contexto crece demasiado, compacta sin perder información crítica.

```python
# context_compactor.py

from typing import List, Dict

def compact_context(messages: List[Dict], max_tokens: int = 8000) -> List[Dict]:
    """
    Compacta el historial de mensajes manteniendo información crítica.
    
    Estrategia:
    1. Mantener siempre el system prompt
    2. Mantener los últimos N mensajes completos
    3. Resumir mensajes antiguos
    """
    
    # Tokens aproximados (4 chars = 1 token)
    def estimate_tokens(text: str) -> int:
        return len(text) // 4
    
    # Separar mensajes por importancia
    system_msg = next((m for m in messages if m['role'] == 'system'), None)
    recent_messages = messages[-6:]  # Últimos 3 intercambios
    old_messages = messages[1:-6] if len(messages) > 7 else []
    
    # Resumir mensajes antiguos si exceden el límite
    if old_messages:
        old_summary = summarize_messages(old_messages)
        return [
            system_msg,
            {"role": "system", "content": f"Resumen de conversación previa:\n{old_summary}"},
            *recent_messages
        ]
    
    return messages

def summarize_messages(messages: List[Dict]) -> str:
    """Resume una lista de mensajes en puntos clave."""
    # En producción, usar Claude Haiku para resumir
    key_points = []
    for msg in messages:
        if 'code' in msg.get('content', '').lower():
            key_points.append(f"- Código discutido: {extract_function_names(msg['content'])}")
        if 'error' in msg.get('content', '').lower():
            key_points.append(f"- Error mencionado: {extract_error_type(msg['content'])}")
    return "\n".join(key_points)
```

---

## Paso 5: Chunking para Datos Grandes

Divide datos grandes en chunks procesables.

```python
# chunking.py

import pandas as pd
from typing import Iterator, Tuple

def chunk_dataframe(
    df: pd.DataFrame, 
    chunk_size: int = 1000,
    overlap: int = 100
) -> Iterator[Tuple[int, pd.DataFrame]]:
    """
    Divide un DataFrame en chunks con overlap para contexto.
    
    Args:
        df: DataFrame a dividir
        chunk_size: Filas por chunk
        overlap: Filas de overlap entre chunks
    
    Yields:
        Tupla (chunk_index, chunk_dataframe)
    """
    total_rows = len(df)
    start = 0
    chunk_idx = 0
    
    while start < total_rows:
        end = min(start + chunk_size, total_rows)
        yield chunk_idx, df.iloc[start:end]
        start = end - overlap
        chunk_idx += 1

def estimate_tokens_for_df(df: pd.DataFrame) -> int:
    """Estima tokens necesarios para representar un DataFrame."""
    # Header + stats + sample
    header_tokens = len(df.columns) * 5
    stats_tokens = len(df.columns) * 20
    sample_tokens = min(len(df), 10) * len(df.columns) * 5
    
    return header_tokens + stats_tokens + sample_tokens

# Uso
df = pd.read_csv("large_dataset.csv")
for idx, chunk in chunk_dataframe(df, chunk_size=500):
    tokens_needed = estimate_tokens_for_df(chunk)
    print(f"Chunk {idx}: {len(chunk)} filas, ~{tokens_needed} tokens")
    # Procesar chunk con Claude
```

---

## Paso 6: Skill con Selección Dinámica de Modelo

```bash
mkdir -p .claude/skills/smart-analyze
touch .claude/skills/smart-analyze/SKILL.md
```

Contenido de `.claude/skills/smart-analyze/SKILL.md`:

```markdown
---
name: smart-analyze
description: Análisis con selección automática de modelo
---

# Smart Analyze

## Selección de Modelo

Basándote en el tamaño y complejidad de la tarea:

1. **Evaluar complejidad:**
   - Contar líneas de código/datos
   - Detectar si hay decisiones de diseño
   - Identificar si es tarea mecánica

2. **Seleccionar modelo:**
   
   \`\`\`python
   def select_model(task_info):
       if task_info['requires_architecture_decision']:
           return 'claude-opus-5'
       elif task_info['lines'] > 1000 or task_info['complexity'] == 'high':
           return 'claude-sonnet-5'
       else:
           return 'claude-haiku-4-5-20251001'
   \`\`\`

3. **Ejecutar con modelo seleccionado**
4. **Reportar costo estimado**
```

---

## Conexión con Ejercicios Anteriores

```
┌─────────────────────────────────────────────────────────┐
│              REGLA DE ORO: ¿QUÉ USAR?                 │
├─────────────────────┬──────────────────────────────────┤
│ SKILL               │ Cosas que el agente DEBE SABER   │
│ HOOK                │ Cosas que SIEMPRE SUCEDEN        │
│ SUBAGENT            │ Cosas que SE DELEGAN            │
│ MCP                 │ INTEGRACIÓN con servicios ext.  │
│ CLAUDE.md           │ Memoria + contexto del proyecto │
├─────────────────────┴──────────────────────────────────┤
│ + MODELO: Elegir tier según complejidad de la tarea   │
└─────────────────────────────────────────────────────────┘
```

- **Tema 3 (Skills):** Cada skill puede especificar su modelo preferido
- **Tema 4-5 (Hooks):** Hooks de validación usan Haiku (baratos, rápidos)
- **Tema 7 (Subagents):** Cada subagent puede usar un modelo diferente

## Checklist de Finalización

- [ ] Matriz de selección de modelo entendida
- [ ] settings.json configurado con model overrides
- [ ] Prompt caching habilitado
- [ ] Funciones de context compaction implementadas
- [ ] Chunking para datos grandes funcional
- [ ] Skill con selección dinámica creado

## Recursos Adicionales

- [Pricing por modelo](https://www.anthropic.com/pricing)
- [Prompt Caching Guide](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
- [Context Window Best Practices](https://platform.claude.com/docs/en/build-with-claude/context-windows)

## Tip Avanzado

Usa **cascade de modelos** para optimizar costo:

```python
async def cascade_query(prompt: str) -> str:
    """
    Intenta con Haiku primero, escala si la respuesta 
    indica que necesita más capacidad.
    """
    # Intento 1: Haiku
    response = await query_claude(prompt, model="haiku")
    
    if needs_escalation(response):
        # Intento 2: Sonnet
        response = await query_claude(prompt, model="sonnet")
        
        if needs_escalation(response):
            # Intento 3: Opus
            response = await query_claude(prompt, model="opus")
    
    return response

def needs_escalation(response: str) -> bool:
    """Detecta si la respuesta indica limitaciones del modelo."""
    indicators = [
        "no estoy seguro",
        "esto es complejo",
        "necesitaría más contexto",
        "I'm not certain"
    ]
    return any(ind in response.lower() for ind in indicators)
```
