# Estructura de Directorios y settings.json

**Ejercicio 2 - 15 minutos**

---

## Objetivo

Dominar la estructura de directorios de Claude Code y configurar settings.json para personalizar el comportamiento del CLI.

## Contexto

Claude Code usa una jerarquía de configuración: global (~/.claude/), proyecto (.claude/) y sesión. Entender esta estructura te permite configurar permisos, variables de entorno y comportamientos específicos sin repetir configuración. settings.json es el centro de control para automatizaciones.

## Conceptos Clave

- **~/.claude/:** Configuración global del usuario, aplica a todos los proyectos
- **.claude/:** Configuración específica del proyecto, versionable en git
- **settings.json:** Archivo de configuración principal con permisos, hooks y preferencias
- **Jerarquía de Configuración:** Global → Proyecto → Sesión (el más específico gana)

---

## Paso 1: Explorar la Estructura Global

Examina tu configuración global de Claude Code.

```bash
ls -la ~/.claude/
```

Estructura típica:

```
~/.claude/
├── settings.json          # Configuración global
├── settings.local.json    # Overrides locales (no sincronizar)
├── credentials.json       # Tokens de autenticación
├── projects/              # Memoria de proyectos
│   └── <hash>/
│       └── memory/        # Memorias del proyecto
└── agents/                # Definiciones de agents personalizados
```

**Verificación:** Deberías ver al menos `settings.json` y `credentials.json`.

---

## Paso 2: Crear Estructura de Proyecto

Inicializa la configuración específica del proyecto.

```bash
mkdir -p .claude/agents
mkdir -p .claude/skills
mkdir -p .claude/workflows
touch .claude/settings.json
```

Estructura completa:

```
tu-proyecto/
├── .claude/
│   ├── settings.json      # Permisos y hooks del proyecto
│   ├── agents/            # Definiciones de subagents
│   │   └── analyzer.md    # Agent especializado
│   ├── skills/            # Skills personalizados
│   │   └── analyze-data/  # Un directorio por skill
│   │       └── SKILL.md   # Nombre de archivo fijo
│   └── workflows/         # Workflows complejos
│       └── full-analysis.js
├── CLAUDE.md              # Contexto del proyecto
└── src/                   # Tu código
```

**Verificación:**
```bash
tree .claude/
```

---

## Paso 3: Configurar settings.json del Proyecto

El archivo `.claude/settings.json` controla permisos y comportamientos.

```json
{
  "permissions": {
    "allow": [
      "Bash(python:*)",
      "Bash(pytest:*)",
      "Bash(pip install:*)",
      "Bash(git status)",
      "Bash(git diff:*)",
      "Bash(ls:*)",
      "Bash(cat:*)",
      "Read",
      "Write(src/**)",
      "Write(tests/**)",
      "Edit(src/**)",
      "Edit(tests/**)"
    ],
    "deny": [
      "Bash(rm -rf:*)",
      "Bash(git push --force:*)",
      "Write(.env*)",
      "Write(**/credentials*)"
    ]
  },
  "env": {
    "PYTHONPATH": "./src",
    "LOG_LEVEL": "INFO",
    "ENV": "development"
  },
  "hooks": {}
}
```

**Explicación técnica:**
- `allow`: Lista de herramientas/comandos permitidos sin confirmación
- `deny`: Lista negra que bloquea acciones peligrosas
- `env`: Variables de entorno disponibles en la sesión
- `hooks`: Automatizaciones (lo veremos en Temas 4-5)

**Verificación:**
```bash
cat .claude/settings.json | python -m json.tool
```

> **📌 Importante — de aquí en adelante, los bloques JSON son incrementales, no el archivo completo.** En este ejercicio y en los que siguen (Temas 4, 5, 6, 7...), cada bloque `json` que veas para `settings.json` muestra **solo las claves relevantes a ese paso** (p. ej. sólo `hooks`, o sólo `model`), no el contenido íntegro del archivo. Debes **fusionarlo** con lo que ya tienes — agregar o actualizar esas claves conservando el resto (`permissions`, `env`, hooks de temas anteriores, etc.) — nunca reemplazar el archivo entero. Si le pides ayuda a Claude, dile explícitamente "agrega esto a mi settings.json existente" en lugar de "crea este settings.json": así usará **Edit** (fusión incremental) en vez de **Write** (sobrescritura completa). El Tema 15 incluye un `settings.json` de referencia con todo lo acumulado, por si quieres comparar.

---

## Paso 4: Configurar Permisos Granulares

Los permisos usan patrones glob para control fino.

```json
{
  "permissions": {
    "allow": [
      "Bash(python src/**/*.py)",
      "Bash(pytest tests/ -v)",
      "Bash(pytest tests/ --cov)",
      "Bash(pip install -r requirements*.txt)",
      "Bash(duckdb:*)",
      "Bash(psql -c 'SELECT:*')",
      
      "Read(src/**)",
      "Read(tests/**)",
      "Read(docs/**)",
      "Read(*.md)",
      "Read(*.json)",
      "Read(*.yaml)",
      
      "Write(src/**/*.py)",
      "Write(tests/**/*.py)",
      "Write(docs/**/*.md)",
      
      "Edit(src/**)",
      "Edit(tests/**)"
    ],
    "deny": [
      "Bash(*DROP*)",
      "Bash(*DELETE FROM*)",
      "Bash(*TRUNCATE*)",
      "Write(data/**)",
      "Write(.claude/settings.json)",
      "Bash(pip install)(!-r requirements*.txt)"
    ]
  }
}
```

**Patrones útiles:**
- `*`: Cualquier cosa
- `**`: Cualquier subdirectorio
- `(!pattern)`: Negación

**⚠️ Gotcha común:** La regla `"deny": ["Write(.claude/settings.json)"]` de arriba bloquea la herramienta `Write` sobre ese archivo (evita que un agente sobrescriba sus propios permisos). Es una protección intencional, pero significa que si en un ejercicio posterior (Tema 4-5, al agregar hooks) le pides a Claude que "reescriba settings.json", la operación fallará. La regla `deny` solo cubre `Write`, no `Edit` — así que la solución es pedirle explícitamente a Claude que use **Edit** (modificación incremental) en lugar de Write para tocar `settings.json` una vez que esta regla está activa.

---

## Paso 5: Variables de Entorno por Contexto

Configura variables según el entorno de trabajo.

```json
{
  "env": {
    "PYTHONPATH": "./src:./tests",
    "DATABASE_URL": "postgresql://localhost:5432/dev_db",
    "REDIS_URL": "redis://localhost:6379",
    "LOG_LEVEL": "DEBUG",
    "ENV": "development",
    "ANALYSIS_OUTPUT_DIR": "./output",
    "MAX_WORKERS": "4"
  }
}
```

**Para producción** (en settings.local.json, no commitear):

```json
{
  "env": {
    "DATABASE_URL": "postgresql://prod-host:5432/prod_db",
    "LOG_LEVEL": "WARNING",
    "ENV": "production"
  }
}
```

**Verificación:**
```bash
claude --print-env | grep DATABASE_URL
```

---

## Conexión con Ejercicios Anteriores

- **Tema 1 (CLAUDE.md):** settings.json complementa CLAUDE.md - uno define contexto, otro define permisos
- Los permisos configurados aquí serán usados por Hooks (Tema 4-5) y Skills (Tema 3)

## Checklist de Finalización

- [ ] Estructura global explorada (~/.claude/)
- [ ] Estructura de proyecto creada (.claude/)
- [ ] settings.json configurado con permisos
- [ ] Lista de allow/deny definida
- [ ] Variables de entorno configuradas

## Recursos Adicionales

- [Referencia de permisos](https://docs.anthropic.com/claude-code/permissions)
- [Patrones glob](https://docs.anthropic.com/claude-code/glob-patterns)

## Tip Avanzado

Usa `settings.local.json` para configuración sensible o específica de tu máquina. Agrégalo a `.gitignore`:

```bash
echo ".claude/settings.local.json" >> .gitignore
```

Jerarquía de merge:
1. `~/.claude/settings.json` (global)
2. `.claude/settings.json` (proyecto)
3. `.claude/settings.local.json` (local, no commitear)

El más específico sobrescribe al más general.
