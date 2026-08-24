# Curso Claude Code - Taller Técnico

Curso práctico progresivo sobre Claude Code para equipos técnicos (Data Scientists, Data Analysts, Engineers).

## Descripción

Este curso de **15 temas** te guía desde los fundamentos hasta la construcción de un **Sistema End-to-End de Automatización de Análisis de Datos**. Cada ejercicio construye sobre el anterior, culminando en una arquitectura de producción completa.

## Estructura del Curso

### Módulo 1: Fundamentos (Repaso Rápido)
| Tema | Título | Duración | Archivo |
|------|--------|----------|---------|
| 1 | CLAUDE.md - Memoria del Proyecto | 10 min | [tema-01-claude-md.md](tema-01-claude-md.md) |
| 2 | Estructura de Directorios y settings.json | 15 min | [tema-02-estructura.md](tema-02-estructura.md) |
| 3 | Tu Primer Skill (Básico) | 15 min | [tema-03-primer-skill.md](tema-03-primer-skill.md) |

### Módulo 2: Automatización y Control
| Tema | Título | Duración | Archivo |
|------|--------|----------|---------|
| 4 | Hooks - PreToolUse y PostToolUse | 20 min | [tema-04-hooks-basic.md](tema-04-hooks-basic.md) |
| 5 | Hooks - Lifecycle Completo | 15 min | [tema-05-hooks-lifecycle.md](tema-05-hooks-lifecycle.md) |
| 6 | Elección de Modelo y Optimización de Tokens | 15 min | [tema-06-modelos-tokens.md](tema-06-modelos-tokens.md) |

### Módulo 3: Escalabilidad
| Tema | Título | Duración | Archivo |
|------|--------|----------|---------|
| 7 | Subagents y Aislamiento de Contexto | 20 min | [tema-07-subagents.md](tema-07-subagents.md) |
| 8 | Agent Teams y Comunicación Peer-to-Peer | 20 min | [tema-08-agent-teams.md](tema-08-agent-teams.md) |
| 9 | MCP (Model Context Protocol) Integration | 20 min | [tema-09-mcp.md](tema-09-mcp.md) |

### Módulo 4: Datos y Recuperación
| Tema | Título | Duración | Archivo |
|------|--------|----------|---------|
| 10 | RAG Básico - Chunking y Embeddings | 20 min | [tema-10-rag-basico.md](tema-10-rag-basico.md) |
| 11 | RAG Avanzado - Hybrid Search y Reranking | 20 min | [tema-11-rag-avanzado.md](tema-11-rag-avanzado.md) |
| 12 | Índices Vectoriales y Optimización | 20 min | [tema-12-indices.md](tema-12-indices.md) |

### Módulo 5: Seguridad y Calidad
| Tema | Título | Duración | Archivo |
|------|--------|----------|---------|
| 13 | Red Teaming y Pruebas Adversariales | 20 min | [tema-13-red-teaming.md](tema-13-red-teaming.md) |
| 14 | Evaluación y Testing de Agents | 20 min | [tema-14-evaluacion.md](tema-14-evaluacion.md) |
| 15 | Arquitectura Completa | 30 min | [tema-15-arquitectura.md](tema-15-arquitectura.md) |

**Tiempo total estimado:** ~4 horas

## Deliverable Final

Al completar el curso habrás construido un sistema que:

- Lee datos desde múltiples fuentes (Skill básico)
- Valida automáticamente inputs (Hooks)
- Selecciona modelo óptimo según tarea (Optimización)
- Ejecuta análisis en paralelo (Subagents)
- Conecta a servicios externos (MCP)
- Recupera contexto histórico (RAG)
- Genera reportes documentados (Agent Teams)
- Se defiende contra ataques (Red Teaming)
- Se evalúa automáticamente (Testing)

## Cómo Usar

### Opción 1: Archivos Markdown
Navega los archivos `.md` en orden secuencial. Cada tema incluye:
- Objetivo claro
- Conceptos clave
- Pasos prácticos con código
- Verificaciones
- Conexiones con temas anteriores
- Tips avanzados

### Opción 2: HTML Interactivo
Abre `curso-claude-code.html` en tu navegador para:
- Navegación por tabs
- Búsqueda integrada
- Botones de copy-to-clipboard
- Tracking de progreso
- Dark theme profesional

## ¿Solo tienes 40 minutos?

Usa la **versión lite**: [`../curso-claude-code-lite/`](../curso-claude-code-lite/) — 8 ejercicios de 5 minutos que construyen un proyecto completo (Python + SQL + documentación + QA + pruebas unitarias) tocando todos los elementos del curso. Sin dependencias pesadas: solo `sqlite3` y `pytest`.

## Regla de Oro

Esta tabla aparece en múltiples temas como guía de decisión:

```
┌─────────────────────────────────────────────────────────┐
│              REGLA DE ORO: ¿QUÉ USAR?                 │
├─────────────────────┬──────────────────────────────────┤
│ SKILL               │ Cosas que el agente DEBE SABER   │
│ HOOK                │ Cosas que SIEMPRE SUCEDEN        │
│ SUBAGENT            │ Cosas que SE DELEGAN            │
│ MCP                 │ INTEGRACIÓN con servicios ext.  │
│ CLAUDE.md           │ Memoria + contexto del proyecto │
└─────────────────────┴──────────────────────────────────┘
```

## Prerequisitos

- Conocimientos básicos de Python
- Familiaridad con línea de comandos
- Claude Code instalado (`claude --version`)
- Cuenta de Anthropic con API key

## Dependencias Opcionales

Para los módulos de RAG (10-12):
```bash
pip install sentence-transformers faiss-cpu numpy
```

Para evaluación (14):
```bash
pip install pytest pytest-asyncio
```

## Recursos Adicionales

- [Documentación oficial de Claude Code](https://docs.anthropic.com/claude-code)
- [MCP Specification](https://modelcontextprotocol.io)
- [OWASP LLM Top 10](https://owasp.org/www-project-top-10-for-large-language-model-applications/)

## Estructura de Archivos

```
curso-claude-code/
├── README.md                    # Este archivo
├── curso-claude-code.html       # Versión HTML interactiva
├── tema-01-claude-md.md         # CLAUDE.md - Memoria del Proyecto
├── tema-02-estructura.md        # Estructura y settings.json
├── tema-03-primer-skill.md      # Tu Primer Skill
├── tema-04-hooks-basic.md       # Hooks PreToolUse/PostToolUse
├── tema-05-hooks-lifecycle.md   # Hooks Lifecycle Completo
├── tema-06-modelos-tokens.md    # Modelos y Optimización
├── tema-07-subagents.md         # Subagents
├── tema-08-agent-teams.md       # Agent Teams
├── tema-09-mcp.md               # MCP Integration
├── tema-10-rag-basico.md        # RAG Básico
├── tema-11-rag-avanzado.md      # RAG Avanzado
├── tema-12-indices.md           # Índices Vectoriales
├── tema-13-red-teaming.md       # Red Teaming
├── tema-14-evaluacion.md        # Evaluación y Testing
└── tema-15-arquitectura.md      # Arquitectura Completa
```

