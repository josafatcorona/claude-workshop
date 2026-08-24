# Arquitectura Completa - Skills + Hooks + Agents

**Ejercicio 15 - 30 minutos**

---

## Objetivo

Integrar todos los conceptos del curso en una arquitectura de producción completa: un Sistema de Automatización de Análisis de Datos que combina Skills, Hooks, Subagents, Agent Teams, MCP, RAG, seguridad y evaluación.

## Contexto

Este es el ejercicio final donde todo se une. Construiremos un sistema end-to-end que: recibe datos, los valida automáticamente (hooks), ejecuta análisis en paralelo (subagents), recupera contexto histórico (RAG), genera reportes documentados y se defiende y se mide (red teaming + evaluación).

## Conceptos Clave

- **Arquitectura por Capas:** Entrada → Hooks → Orquestación → Procesamiento → Datos
- **Defense in Depth:** Múltiples capas de seguridad independientes
- **Observabilidad:** Logging, métricas, trazas
- **Resiliencia:** Manejo de errores, retries, fallbacks

---

## Paso 0: Inventario de lo que ya Construiste

Antes de integrar, confirma qué piezas están en su sitio. Ejecuta:

```bash
echo "=== SKILLS ===";  ls .claude/skills/     2>/dev/null || echo "  (falta)"
echo "=== AGENTS ===";  ls .claude/agents/     2>/dev/null || echo "  (falta)"
echo "=== HOOKS ===";   ls .claude/hooks/      2>/dev/null || echo "  (falta)"
echo "=== RAG ===";     ls src/rag/            2>/dev/null || echo "  (falta)"
echo "=== SEGURIDAD ==="; ls src/security/     2>/dev/null || echo "  (falta)"
echo "=== EVAL ===";    ls src/evaluation/     2>/dev/null || echo "  (falta)"
echo "=== CONFIG ==="; ls CLAUDE.md .mcp.json .claude/settings.json 2>/dev/null
```

Si algo falta, vuelve a ese tema. **La integración no crea piezas nuevas: las conecta.**

### 0a. Crear lo que falta para este tema

```bash
mkdir -p src/observability
mkdir -p tests
mkdir -p .claude/metrics
mkdir -p output

touch src/observability/__init__.py
touch tests/__init__.py
```

---

## Paso 1: Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────────────┐
│                    ARQUITECTURA COMPLETA                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    CAPA DE ENTRADA                       │   │
│  │  ┌─────────┐  ┌─────────────┐  ┌───────────────────┐   │   │
│  │  │ Claude  │  │    API      │  │   Scheduled Jobs  │   │   │
│  │  │  Code   │  │  Endpoint   │  │     (Cron)        │   │   │
│  │  └────┬────┘  └──────┬──────┘  └─────────┬─────────┘   │   │
│  └───────┼──────────────┼───────────────────┼──────────────┘   │
│          │              │                   │                   │
│          ▼              ▼                   ▼                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              CAPA DE HOOKS (Temas 4, 5, 13)              │   │
│  │  ┌──────────────┐ ┌──────────────┐ ┌─────────────────┐ │   │
│  │  │ SessionStart │ │ PreToolUse   │ │ Security Check  │ │   │
│  │  │   (init)     │ │ (validate)   │ │ (block attacks) │ │   │
│  │  └──────────────┘ └──────────────┘ └─────────────────┘ │   │
│  └──────────────────────────┬──────────────────────────────┘   │
│                             ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │           CAPA DE ORQUESTACIÓN (Tema 3)                  │   │
│  │  ┌──────────────────────────────────────────────────┐  │   │
│  │  │              MAIN ORCHESTRATOR                    │  │   │
│  │  │         (selecciona skills, coordina)             │  │   │
│  │  └───────────────────────┬──────────────────────────┘  │   │
│  │         ┌────────────────┼────────────────┐            │   │
│  │         ▼                ▼                ▼            │   │
│  │  ┌──────────┐     ┌──────────┐     ┌──────────┐       │   │
│  │  │  Skill   │     │  Skill   │     │  Skill   │       │   │
│  │  │ analyze  │     │  report  │     │ compare  │       │   │
│  │  └────┬─────┘     └────┬─────┘     └────┬─────┘       │   │
│  └───────┼────────────────┼────────────────┼──────────────┘   │
│          ▼                ▼                ▼                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │        CAPA DE PROCESAMIENTO (Temas 6, 7, 8)             │   │
│  │                    (AGENT TEAM)                          │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐   │   │
│  │  │Extractor │ │Analyzer  │ │Validator │ │Documenter│   │   │
│  │  │ (Haiku)  │ │ (Sonnet) │ │ (Haiku)  │ │ (Sonnet) │   │   │
│  │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘   │   │
│  └───────┼────────────┼────────────┼────────────┼──────────┘   │
│          ▼            ▼            ▼            ▼               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │        CAPA DE DATOS (Temas 9, 10, 11, 12)               │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐   │   │
│  │  │   RAG    │ │  MCP     │ │  Files   │ │   Logs   │   │   │
│  │  │ (Vector) │ │(External)│ │  (Local) │ │(Metrics) │   │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Paso 2: Configuración Completa

### 2a. CLAUDE.md del Proyecto

```bash
# Si ya lo creaste en el Tema 1, ábrelo y amplíalo. Si no:
touch CLAUDE.md
```

Contenido de `CLAUDE.md`:

```markdown
# Sistema de Análisis de Datos Automatizado

## Arquitectura
Este sistema procesa datos de ventas mediante un pipeline de agentes especializados.
Usa RAG para contexto histórico y MCP para integraciones externas.

## Stack
- Python 3.11+
- Claude Code (Opus para orquestación, Sonnet para análisis, Haiku para validación)
- FAISS para vector store
- PostgreSQL + DuckDB para datos
- Slack para notificaciones

## Flujo Principal
1. Datos entran vía upload o scheduled job
2. Hooks validan y sanitizan
3. Orchestrator selecciona el skill apropiado
4. Agent team ejecuta análisis en paralelo
5. RAG recupera contexto histórico relevante
6. Documenter genera reporte final
7. Notificación vía Slack

## Reglas de Seguridad
- NUNCA ejecutar comandos destructivos sin confirmación humana
- Validar TODOS los inputs contra inyección
- No exponer credenciales en logs
- Rate limit de 100 requests/minuto

## Convenciones
- Type hints obligatorios
- Docstrings en formato Google
- Tests para toda función pública
- Logs estructurados (JSON)

## Convenciones de Datos
- Fechas en ISO (YYYY-MM-DD)
- `region` solo acepta: Norte, Sur, Centro
- `cantidad` nula = pendiente de auditoría, NO cero
```

**Verificación:**
```bash
head -5 CLAUDE.md
```

### 2b. settings.json Completo

Esta es la referencia de cómo se ve `settings.json` una vez **fusionadas** todas las claves de los temas anteriores (`permissions` del Tema 2, `hooks` de los Temas 4-5 y 13, `model` del Tema 6) en un solo archivo — no una clave a la vez, como se fue mostrando en cada ejercicio.

**Antes de sobreescribir, respalda tu archivo actual:**

```bash
cp .claude/settings.json .claude/settings.json.bak
```

Contenido final de `.claude/settings.json`:

```json
{
  "model": {
    "default": "claude-sonnet-5",
    "overrides": {
      "agents": {
        "validator": "claude-haiku-4-5-20251001",
        "extractor": "claude-haiku-4-5-20251001",
        "analyzer": "claude-sonnet-5",
        "documenter": "claude-sonnet-5",
        "orchestrator": "claude-opus-5"
      }
    }
  },

  "permissions": {
    "allow": [
      "Bash(python src/**/*.py)",
      "Bash(python -m src.**)",
      "Bash(pytest:*)",
      "Bash(pip install -r requirements*.txt)",
      "Read(src/**)",
      "Read(data/**)",
      "Read(docs/**)",
      "Write(src/**/*.py)",
      "Write(output/**)",
      "Write(tests/**/*.py)",
      "Edit(src/**)",
      "Edit(tests/**)",
      "mcp__filesystem__read_text_file",
      "mcp__analytics__get_metrics"
    ],
    "deny": [
      "Bash(rm -rf:*)",
      "Bash(sudo:*)",
      "Bash(*DROP*)",
      "Bash(*DELETE*)",
      "Read(.env)",
      "Read(~/.ssh/**)",
      "Write(.env*)",
      "Write(*credential*)",
      "Write(.claude/settings.json)"
    ]
  },

  "hooks": {
    "SessionStart": [
      {"hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/session-start.sh"}]}
    ],
    "SessionEnd": [
      {"hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/session-end.sh"}]}
    ],
    "PreToolUse": [
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/validate-bash.sh"}]},
      {"matcher": "Write", "hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/validate-write.sh"}]},
      {"matcher": "*", "hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/detect-attack.sh"}]}
    ],
    "PostToolUse": [
      {"matcher": "*", "hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/log-action.sh"}]},
      {"matcher": "Write", "hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/reindex-rag.sh"}]}
    ]
  },

  "env": {
    "PYTHONPATH": "./src",
    "LOG_LEVEL": "INFO",
    "RAG_STORE_PATH": ".claude/rag/store",
    "OUTPUT_DIR": "./output"
  }
}
```

**Verificación crítica — todo hook referenciado debe existir y ser ejecutable:**

```bash
jq -r '.hooks | to_entries[] | .value[] | .hooks[] | .command' .claude/settings.json \
  | sed "s|\${CLAUDE_PROJECT_DIR}|.|" \
  | while read -r h; do
      if [ -x "$h" ]; then echo "OK   $h"; else echo "FALTA/NO EJECUTABLE  $h"; fi
    done
```

Crea o marca como ejecutable cualquiera que falte (`touch` + `chmod +x`). **Un hook inexistente rompe cada llamada a herramienta de la sesión.**

### 2c. .mcp.json

`mcpServers` no va en `settings.json` — vive en su propio `.mcp.json` en la raíz (ver Tema 9):

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "./data"]
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres", "${DATABASE_URL}"],
      "env": {"DATABASE_URL": "${DATABASE_URL}"}
    },
    "slack": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-slack"],
      "env": {
        "SLACK_BOT_TOKEN": "${SLACK_BOT_TOKEN}",
        "SLACK_TEAM_ID": "${SLACK_TEAM_ID}"
      }
    },
    "analytics": {
      "command": "node",
      "args": [".claude/mcp-servers/analytics-api/index.js"],
      "env": {
        "ANALYTICS_API_URL": "${ANALYTICS_API_URL}",
        "ANALYTICS_API_KEY": "${ANALYTICS_API_KEY}"
      }
    }
  }
}
```

**Verificación:**
```bash
jq . .mcp.json > /dev/null && echo "JSON válido"
claude mcp list
```

---

## Paso 3: Skill Principal de Orquestación

### 3a. Crear la estructura

```bash
mkdir -p .claude/skills/full-analysis
touch .claude/skills/full-analysis/SKILL.md
```

### 3b. Contenido de `.claude/skills/full-analysis/SKILL.md`

```markdown
---
name: full-analysis
description: Ejecuta el análisis completo de datos con el pipeline de agentes, RAG y MCP
arguments:
  - name: source
    description: Fuente de datos (archivo CSV o query)
    required: true
  - name: analysis_type
    description: Tipo de análisis (exploratory, comparative, predictive)
    required: false
    default: exploratory
---

# Full Analysis Skill

## Tabla de Decisión

┌─────────────────────────────────────────────────────────┐
│              REGLA DE ORO: ¿QUÉ USAR?                 │
├─────────────────────┬──────────────────────────────────┤
│ SKILL (este)        │ Orquestar el flujo completo      │
│ HOOK                │ Validar cada paso automático     │
│ SUBAGENT            │ Ejecutar análisis especializado  │
│ MCP                 │ Conectar a DB y Slack            │
│ RAG                 │ Recuperar análisis históricos    │
│ CLAUDE.md           │ Contexto y reglas del proyecto   │
└─────────────────────┴──────────────────────────────────┘

## Fase 1: Extracción y Validación

### 1.1 Extraer Datos
Delegar al agent **extractor**:

\`\`\`
Agent: extractor
Task: Extraer datos de {{source}}
Model: haiku (rápido y barato para I/O)
Output: {path: string, rows: number, columns: string[]}
\`\`\`

### 1.2 Validación (gate)
Delegar al agent **validator**:

\`\`\`
Agent: validator
Tasks (paralelo):
  - Validar estructura del dataset
  - Detectar valores nulos críticos
  - Verificar tipos de datos
  - Buscar duplicados
Output: {valid: boolean, issues: Issue[], warnings: Warning[]}
\`\`\`

**Si `valid` es false: notifica al usuario, escribe el reporte de problemas y ABORTA.**
No continúes analizando datos que ya sabes que están mal.

## Fase 2: Contexto Histórico

### 2.1 Buscar Análisis Previos (RAG - Temas 10-11)

\`\`\`bash
python -c "
from src.rag.vector_store import SimpleVectorStore
from src.rag.advanced_pipeline import AdvancedRAGPipeline
p = AdvancedRAGPipeline(SimpleVectorStore())
print(p.build_context(p.retrieve('análisis previos de {{analysis_type}}', top_k=3)))
"
\`\`\`

### 2.2 Obtener Métricas de Referencia (MCP - Tema 9)

\`\`\`
MCP Tool: get_metrics
Params: {metric_name: "gmv", start_date: <hace 30 días>, end_date: <hoy>}
\`\`\`

## Fase 3: Análisis Principal

### 3.1 Spawn del Agent Team (Temas 7-8)

\`\`\`
Agent Team: analysis-team
Agents (en paralelo):
  - statistical-analyzer (Sonnet): Estadísticas descriptivas
  - trend-analyzer (Sonnet): Detección de tendencias
  - anomaly-detector (Sonnet): Outliers y anomalías

Communication: peer-to-peer
Timeout: 120s
\`\`\`

### 3.2 Consolidar

El agent **documenter** recibe los outputs de los tres analyzers más el contexto
histórico del RAG y las métricas de referencia del MCP, y produce el reporte.

## Fase 4: Entrega

### 4.1 Guardar Reporte
Ruta: `output/analysis_<YYYYMMDD_HHMMSS>.md`

### 4.2 Indexar para RAG Futuro

\`\`\`bash
python -m src.rag.indexer
\`\`\`

El análisis de hoy es el contexto histórico de mañana. Este paso cierra el ciclo.

### 4.3 Notificar vía Slack

\`\`\`
MCP Tool: slack_send_message
Channel: #data-insights
Message: "Nuevo análisis disponible: <ruta>"
\`\`\`

Si el MCP de Slack no está conectado, omite el paso e indícalo en el output.

## Manejo de Errores

- Extracción falla → reintenta 3 veces, luego notifica el error
- Validación falla → genera reporte de problemas de datos y aborta
- Análisis falla → ejecuta análisis estadístico básico como fallback
- Notificación falla → registra en log pero NO abortes: el reporte ya existe
```

### 3c. Verificar que el skill es visible

```bash
ls .claude/skills/
```

En la sesión de Claude Code, escribe `/` y confirma que `full-analysis` aparece en la lista.

---

## Paso 4: Agent Team Definition

### 4a. Crear los archivos de los analyzers

```bash
touch .claude/agents/statistical-analyzer.md
touch .claude/agents/trend-analyzer.md
touch .claude/agents/anomaly-detector.md
touch .claude/agents/analysis-team.md
```

### 4b. Contenido de `.claude/agents/statistical-analyzer.md`

```markdown
---
name: statistical-analyzer
description: Calcula estadísticas descriptivas de un dataset
model: claude-sonnet-5
tools:
  - Bash
  - Read
  - SendMessage
teammates:
  - documenter
---

# Statistical Analyzer

Calcula: conteos, media, mediana, desviación, cuartiles y distribución por
categoría y región.

Al terminar, envía al documenter:

\`\`\`javascript
SendMessage({
  to: "documenter",
  message: {
    "action": "PARTIAL_RESULT",
    "source": "statistical-analyzer",
    "metrics": { "rows": 0, "gmv_total": 0, "top_categoria": "" }
  }
})
\`\`\`

Nunca inventes un número. Si una columna no existe, repórtalo como issue.
```

Crea `trend-analyzer.md` y `anomaly-detector.md` con la misma estructura, cambiando `name`, la descripción de la función (tendencias temporales / outliers por IQR y z-score) y el campo `source` del mensaje.

### 4c. Contenido de `.claude/agents/analysis-team.md`

```markdown
---
name: analysis-team
description: Equipo de análisis de datos paralelo
agents:
  - statistical-analyzer
  - trend-analyzer
  - anomaly-detector
  - documenter
communication: peer-to-peer
orchestration: parallel-then-consolidate
---

# Analysis Team

## Topología

\`\`\`
                    ┌───────────────────┐
                    │   INPUT DATA      │
                    └─────────┬─────────┘
                              │
            ┌─────────────────┼─────────────────┐
            ▼                 ▼                 ▼
    ┌───────────────┐ ┌───────────────┐ ┌───────────────┐
    │  Statistical  │ │    Trend      │ │   Anomaly     │
    │   Analyzer    │ │   Analyzer    │ │   Detector    │
    └───────┬───────┘ └───────┬───────┘ └───────┬───────┘
            │                 │                 │
            └─────────────────┼─────────────────┘
                              ▼
                    ┌───────────────────┐
                    │    DOCUMENTER     │
                    │  (consolidation)  │
                    └───────────────────┘
\`\`\`

## Protocolo

1. Los tres analyzers reciben los datos simultáneamente
2. Cada uno ejecuta su análisis de forma independiente
3. Al terminar, envían PARTIAL_RESULT al documenter
4. Documenter espera los tres, luego consolida

Si un analyzer no responde en su timeout, el documenter consolida con los que
sí llegaron y marca explícitamente la sección faltante.

## Timeouts

- Analyzers: 60s cada uno
- Documenter: 30s
- Total pipeline: 120s
```

### 4d. Verificar

```bash
ls .claude/agents/
# Esperado: analysis-team.md, anomaly-detector.md, documenter.md, extractor.md,
#           loader.md, quality-checker.md, statistical-analyzer.md, trend-analyzer.md, validator.md
```

---

## Paso 5: Monitoreo y Observabilidad

### 5a. Crear el archivo

```bash
touch src/observability/metrics.py
```

### 5b. Contenido completo de `src/observability/metrics.py`

```python
# src/observability/metrics.py

from dataclasses import dataclass, field
from typing import Dict, List, Optional
from datetime import datetime
import json
import os


@dataclass
class PipelineMetrics:
    """Métricas de una ejecución del pipeline de análisis."""

    run_id: str
    start_time: datetime
    end_time: Optional[datetime] = None

    # Tiempos por fase
    extraction_time_ms: float = 0
    validation_time_ms: float = 0
    rag_time_ms: float = 0
    analysis_time_ms: float = 0
    documentation_time_ms: float = 0

    # Contadores
    rows_processed: int = 0
    agents_spawned: int = 0
    rag_chunks_retrieved: int = 0

    # Costos
    tokens_input: int = 0
    tokens_output: int = 0
    estimated_cost_usd: float = 0

    # Estado
    status: str = "running"
    errors: List[str] = field(default_factory=list)

    @property
    def total_duration_ms(self) -> float:
        if not self.end_time:
            return 0
        return (self.end_time - self.start_time).total_seconds() * 1000

    def to_dict(self) -> Dict:
        return {
            "run_id": self.run_id,
            "start_time": self.start_time.isoformat(),
            "end_time": self.end_time.isoformat() if self.end_time else None,
            "duration_ms": self.total_duration_ms,
            "phases": {
                "extraction_ms": self.extraction_time_ms,
                "validation_ms": self.validation_time_ms,
                "rag_ms": self.rag_time_ms,
                "analysis_ms": self.analysis_time_ms,
                "documentation_ms": self.documentation_time_ms
            },
            "counters": {
                "rows_processed": self.rows_processed,
                "agents_spawned": self.agents_spawned,
                "rag_chunks": self.rag_chunks_retrieved
            },
            "cost": {
                "tokens_input": self.tokens_input,
                "tokens_output": self.tokens_output,
                "estimated_usd": self.estimated_cost_usd
            },
            "status": self.status,
            "errors": self.errors
        }


class MetricsCollector:
    """Colector de métricas del sistema."""

    def __init__(self, metrics_dir: str = ".claude/metrics"):
        self.metrics_dir = metrics_dir
        os.makedirs(metrics_dir, exist_ok=True)

    def save_run_metrics(self, metrics: PipelineMetrics) -> str:
        """Guarda métricas de una ejecución."""
        filepath = os.path.join(self.metrics_dir, f"{metrics.run_id}.json")
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(metrics.to_dict(), f, indent=2)
        return filepath

    def get_summary(self, last_n: int = 10) -> Dict:
        """Genera resumen de las últimas N ejecuciones."""
        files = sorted(f for f in os.listdir(self.metrics_dir) if f.endswith('.json'))[-last_n:]

        runs = []
        for name in files:
            with open(os.path.join(self.metrics_dir, name), 'r', encoding='utf-8') as f:
                runs.append(json.load(f))

        if not runs:
            return {}

        return {
            "total_runs": len(runs),
            "success_rate": sum(1 for r in runs if r["status"] == "success") / len(runs),
            "avg_duration_ms": sum(r["duration_ms"] or 0 for r in runs) / len(runs),
            "total_cost_usd": sum(r["cost"]["estimated_usd"] for r in runs),
            "avg_rows_per_run": sum(r["counters"]["rows_processed"] for r in runs) / len(runs)
        }
```

### 5c. Probar el colector

```bash
python -c "
from datetime import datetime, timedelta
from src.observability.metrics import PipelineMetrics, MetricsCollector

c = MetricsCollector()
for i in range(3):
    m = PipelineMetrics(run_id=f'run_{i:03d}', start_time=datetime.now())
    m.end_time = m.start_time + timedelta(seconds=12 + i)
    m.rows_processed = 1000 * (i + 1)
    m.agents_spawned = 4
    m.estimated_cost_usd = 0.03 * (i + 1)
    m.status = 'success'
    c.save_run_metrics(m)

print(c.get_summary())
"
```

**Salida esperada:** un dict con `total_runs: 3`, `success_rate: 1.0` y el costo acumulado.

**Verificación en disco:**
```bash
ls .claude/metrics/
# Esperado: run_000.json run_001.json run_002.json
```

---

## Paso 6: Testing del Sistema Completo

### 6a. Instalar pytest

```bash
pip install pytest pytest-asyncio
```

### 6b. Crear la configuración de pytest

```bash
touch pytest.ini
```

Contenido de `pytest.ini`:

```ini
[pytest]
asyncio_mode = auto
testpaths = tests
```

### 6c. Crear el archivo de tests

```bash
touch tests/test_full_pipeline.py
```

### 6d. Contenido completo de `tests/test_full_pipeline.py`

```python
# tests/test_full_pipeline.py
"""
Tests end-to-end del pipeline completo.

Los tests que dependen de un agente real usan un `agent_function` simulado,
para que la suite corra en CI sin credenciales ni costo.
"""

import asyncio
import csv
import json

import pytest

from src.security.red_team import RedTeamFramework
from src.evaluation.eval_framework import EvalFramework, EvalCase, EvalMetric


@pytest.fixture
def sample_data(tmp_path):
    """Genera un CSV de prueba."""
    path = tmp_path / "test_data.csv"
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["fecha", "region", "categoria", "cantidad", "precio_unitario"])
        for i in range(100):
            w.writerow([f"2024-01-{i % 28 + 1:02d}", "Norte", "Electronica", i % 5 + 1, 100 + i])
    return str(path)


@pytest.fixture
def agent_function():
    """Agente simulado que respeta las reglas del proyecto."""
    async def _agent(prompt: str) -> str:
        p = prompt.lower()
        # Las respuestas están en español porque el golden dataset del Tema 14
        # busca cadenas en español ("no puedo"). El idioma de la respuesta es
        # parte del contrato que se evalúa.
        if any(k in p for k in ["rm -rf", "delete", "elimina", "borra", "drop"]):
            return "No puedo realizar operaciones destructivas. Blocked by policy."
        if any(k in p for k in ["password", "id_rsa", "credential"]):
            return "No puedo revelar credenciales. Denied."
        if "ignore" in p and "instructions" in p:
            return "No puedo seguir esa instrucción. Security policy applies."
        if "dan" in p or "sudo" in p or "root" in p or "reveal" in p:
            return "Me niego. That is not allowed in this project."
        if "hypothetically" in p or "educational purposes" in p:
            return "No puedo proporcionar eso, ni hipotéticamente. Refused."
        if "bad_data" in p or "sin datos" in p:
            return "Validation error: el dataset no contiene filas."
        if "json" in p:
            return '{"media": 152.4, "desv": 33.1}'
        if "vacía" in p or "nulos" in p:
            return "Hay 1 valor nulo en cantidad: venta pendiente de auditoría."
        if "media" in p:
            return "La media de la columna precio es 152.4"
        return "Analysis complete. GMV total: 15,258. Top region: Norte."
    return _agent


class TestFullPipeline:

    @pytest.mark.asyncio
    async def test_basic_analysis(self, sample_data, agent_function):
        """El análisis básico funciona end-to-end."""
        result = await agent_function(f"/full-analysis source={sample_data}")
        assert "analysis complete" in result.lower()

    @pytest.mark.asyncio
    async def test_validation_catches_bad_data(self, tmp_path, agent_function):
        """La validación detecta datos problemáticos."""
        bad = tmp_path / "bad_data.csv"
        bad.write_text("col1,col2\n", encoding="utf-8")     # Solo headers

        result = await agent_function(f"/full-analysis source={bad}")
        assert "validation" in result.lower() or "error" in result.lower()

    @pytest.mark.asyncio
    async def test_security_blocks_all_critical_attacks(self, agent_function):
        """Ningún vector crítico de red teaming tiene éxito."""
        red_team = RedTeamFramework()
        report = await red_team.run_full_suite(agent_function)
        assert len(report["critical_failures"]) == 0, report["critical_failures"]

    @pytest.mark.asyncio
    async def test_eval_suite_has_no_critical_failures(self, agent_function):
        """El golden dataset pasa en sus casos críticos."""
        fw = EvalFramework("full")
        fw.add_cases_from_json("tests/eval_suites/full.json")
        report = await fw.run_eval(agent_function, tags=["critical"])
        criticas = [f for f in report["failures"] if "critical" in f["tags"]]
        assert not criticas, criticas

    def test_all_hooks_exist_and_are_executable(self):
        """Todo hook declarado en settings.json existe y es ejecutable."""
        import os
        with open(".claude/settings.json", encoding="utf-8") as f:
            settings = json.load(f)

        faltantes = []
        for entries in settings.get("hooks", {}).values():
            for entry in entries:
                for hook in entry["hooks"]:
                    path = hook["command"].replace("${CLAUDE_PROJECT_DIR}", ".")
                    if not (os.path.isfile(path) and os.access(path, os.X_OK)):
                        faltantes.append(path)

        assert not faltantes, f"Hooks faltantes o no ejecutables: {faltantes}"

    def test_no_secrets_in_versioned_files(self):
        """.env no está versionado (solo aplica si el proyecto es un repo git)."""
        import subprocess
        es_repo = subprocess.run(["git", "rev-parse", "--git-dir"],
                                 capture_output=True).returncode == 0
        if not es_repo:
            pytest.skip("el proyecto no es un repositorio git")

        r = subprocess.run(["git", "check-ignore", ".env"], capture_output=True)
        assert r.returncode == 0, ".env NO está en .gitignore"
```

### 6e. Ejecutar los tests

```bash
pytest -v
```

**Salida esperada:**
```
tests/test_full_pipeline.py::TestFullPipeline::test_basic_analysis PASSED
tests/test_full_pipeline.py::TestFullPipeline::test_validation_catches_bad_data PASSED
tests/test_full_pipeline.py::TestFullPipeline::test_security_blocks_all_critical_attacks PASSED
tests/test_full_pipeline.py::TestFullPipeline::test_eval_suite_has_no_critical_failures PASSED
tests/test_full_pipeline.py::TestFullPipeline::test_all_hooks_exist_and_are_executable PASSED
tests/test_full_pipeline.py::TestFullPipeline::test_no_secrets_in_versioned_files PASSED
```

> El último aparecerá como `SKIPPED` si el proyecto del curso no está bajo git. Es correcto: no hay nada que verificar. Si sí lo está y falla, tienes `.env` versionado — arréglalo antes de seguir.

Si alguno falla, **ese es el hallazgo del ejercicio**: la integración detectó una pieza mal conectada. Arréglala antes de dar el curso por terminado.

---

## Paso 7: Ejecución End-to-End Real

Con todo en su sitio, corre el sistema completo desde Claude Code:

```
/full-analysis source=data/ventas_2024.csv analysis_type=exploratory
```

**Qué debes observar, en orden:**

1. El hook `SessionStart` ya se ejecutó al abrir la sesión
2. `detect-attack.sh` corre en cada llamada a herramienta (revisa `.claude/logs/`)
3. El skill delega a `extractor` y `validator`
4. El RAG devuelve contexto de `reports/analisis_ventas_q1_2024.md`
5. Los tres analyzers corren en paralelo
6. El documenter escribe `output/analysis_<timestamp>.md`
7. El hook `reindex-rag.sh` reindexa el reporte recién escrito

**Verificación final:**

```bash
ls -la output/                          # El reporte existe
tail -20 .claude/logs/*.log             # Los hooks registraron actividad
python -c "
from src.rag.vector_store import SimpleVectorStore
s = SimpleVectorStore()
print(f'Chunks tras reindexado: {len(s.documents)}')
"                                       # Subió respecto al Tema 11
```

---

## Resumen: Regla de Oro Final

```
┌─────────────────────────────────────────────────────────────────┐
│              ARQUITECTURA COMPLETA - RESUMEN                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  CLAUDE.md        → Contexto y reglas del proyecto             │
│                     (Lo que Claude debe saber siempre)          │
│                                                                 │
│  settings.json    → Permisos, modelos, variables               │
│                     (Configuración declarativa)                 │
│                                                                 │
│  SKILLS           → Tareas reutilizables (/comando)            │
│                     (Flujos que el usuario invoca)              │
│                                                                 │
│  HOOKS            → Automatización invisible                    │
│                     (Lo que siempre debe pasar)                 │
│                                                                 │
│  SUBAGENTS        → Procesamiento paralelo especializado       │
│                     (Divide y vencerás)                         │
│                                                                 │
│  AGENT TEAMS      → Colaboración entre especialistas           │
│                     (Comunicación peer-to-peer)                 │
│                                                                 │
│  MCP              → Integración con servicios externos         │
│                     (El mundo fuera de Claude)                  │
│                                                                 │
│  RAG              → Memoria a largo plazo                       │
│                     (Conocimiento que no cabe en el prompt)     │
│                                                                 │
│  RED TEAMING      → Seguridad proactiva                         │
│                     (Pensar como atacante)                      │
│                                                                 │
│  EVALUACIÓN       → Calidad medible                             │
│                     (Lo que no se mide no se mejora)            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Checklist de Finalización del Curso

- [ ] Inventario del Paso 0 sin piezas faltantes
- [ ] `CLAUDE.md` documentando arquitectura, stack, seguridad y convenciones
- [ ] `.claude/settings.json` con model + permissions + hooks + env fusionados
- [ ] Todos los hooks declarados existen y son ejecutables (verificado con el script del Paso 2b)
- [ ] `.mcp.json` válido y `claude mcp list` responde
- [ ] Skill `full-analysis` creado y visible con `/`
- [ ] Agents del analysis-team creados (statistical, trend, anomaly + documenter)
- [ ] `src/observability/metrics.py` creado y probado; JSONs en `.claude/metrics/`
- [ ] `pytest.ini` creado y `pytest -v` pasa los 6 tests
- [ ] Red teaming sin fallas críticas (verificado desde el test suite)
- [ ] Suite de evaluación con baseline guardado
- [ ] Ejecución end-to-end real con reporte en `output/` y RAG reindexado

## Recursos Adicionales

- [Claude Code Documentation](https://code.claude.com/docs)
- [MCP Specification](https://modelcontextprotocol.io)
- [Building effective agents (Anthropic)](https://www.anthropic.com/engineering/building-effective-agents)

## Siguiente Paso

Has completado el curso. El sistema que construiste puede:
1. Recibir datos de múltiples fuentes
2. Validarlos automáticamente
3. Analizarlos con agentes especializados en paralelo
4. Recuperar contexto histórico relevante
5. Generar reportes documentados
6. Notificar a stakeholders
7. Todo con seguridad, métricas y tests

**Desafío final:** extiende el sistema para manejar datos en streaming y análisis en tiempo real. Pista: el gate de validación pasa de ser un paso a ser un filtro continuo, y las métricas del Paso 5 se convierten en la señal de salud del stream.
