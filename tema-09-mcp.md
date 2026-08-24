# MCP (Model Context Protocol) Integration

**Ejercicio 9 - 20 minutos**

---

## Objetivo

Integrar Claude Code con servicios externos mediante MCP, extendiendo las capacidades del agente con APIs, bases de datos y herramientas de terceros.

## Contexto

MCP es el protocolo que permite a Claude interactuar con el mundo exterior de manera segura y estandarizada. En lugar de escribir integraciones custom, MCP proporciona un framework donde "servers" exponen herramientas que Claude puede usar. Piensa en ello como plugins estandarizados.

## Conceptos Clave

- **MCP Server:** Proceso que expone herramientas a Claude vía protocolo estándar
- **MCP Tool:** Función específica que Claude puede invocar (ej: `read_file`, `query`)
- **Resources:** Datos que el MCP server puede proporcionar (ej: catálogo de métricas)
- **Transport:** Cómo se comunican Claude y el server (stdio, http, sse)

---

## Paso 0: Preparación del Entorno

Antes de empezar, verifica que tienes lo necesario. Ejecuta cada comando y confirma la salida:

```bash
# 1. Estar en la raíz del proyecto del curso
pwd
# Esperado: la carpeta donde creaste .claude/ en los temas 1-2

# 2. Node.js instalado (los MCP servers de referencia corren con npx)
node --version    # Esperado: v18.0.0 o superior
npx --version     # Esperado: 9.x o superior

# 3. Claude Code instalado
claude --version

# 4. jq para inspeccionar JSON (opcional pero útil en las verificaciones)
jq --version
```

Si `node` no está instalado, descárgalo de [nodejs.org](https://nodejs.org) antes de continuar.

Crea la carpeta de datos que usaremos en la demo (si no existe ya del Tema 3):

```bash
mkdir -p data output
ls -la data
```

---

## Paso 1: Entender Dónde Vive la Configuración MCP

Los MCP servers **no** se configuran en `.claude/settings.json`. Viven en su propio archivo:

| Archivo | Alcance | Se versiona en git |
|---------|---------|--------------------|
| `.mcp.json` (raíz del proyecto) | Todo el equipo del proyecto | Sí |
| `~/.claude.json` | Solo tu usuario, todos los proyectos | No |
| `.claude/settings.local.json` | Solo tú, solo este proyecto | No (gitignore) |

En este ejercicio usaremos `.mcp.json` a nivel proyecto.

### 1a. Crear el archivo

```bash
# Desde la raíz del proyecto
touch .mcp.json
```

### 1b. Escribir el contenido inicial

Abre `.mcp.json` en tu editor y pega **exactamente** esto:

```json
{
  "mcpServers": {}
}
```

### 1c. Verificar que es JSON válido

```bash
jq . .mcp.json
# Esperado: { "mcpServers": {} }
# Si da error de parseo, revisa comas y llaves.
```

---

## Paso 2: Tu Primer MCP Server (Filesystem) — Ruta Garantizada

Empezamos con el server **filesystem**, que no requiere credenciales ni base de datos. Funciona en cualquier máquina y es el mejor para aprender el flujo completo.

### 2a. Registrar el server con la CLI

La forma recomendada es dejar que Claude Code escriba el `.mcp.json` por ti:

```bash
claude mcp add --scope project filesystem -- npx -y @modelcontextprotocol/server-filesystem ./data
```

**Desglose del comando:**
- `claude mcp add` → subcomando para registrar un server
- `--scope project` → escribe en `.mcp.json` (compartido); alternativas: `user`, `local`
- `filesystem` → el nombre con el que Claude conocerá al server
- `--` → separador: todo lo que sigue es el comando que lanza el server
- `npx -y @modelcontextprotocol/server-filesystem ./data` → descarga y ejecuta el server, dándole acceso **solo** a `./data`

### 2b. Verificar qué escribió la CLI

```bash
cat .mcp.json
```

Deberías ver algo equivalente a:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "./data"]
    }
  }
}
```

> **Nota:** también puedes escribir este bloque a mano en `.mcp.json` — la CLI solo es un atajo. Lo importante es entender la forma: `command` + `args` + (opcional) `env`.

### 2c. Reiniciar Claude Code

Los MCP servers se cargan **al iniciar la sesión**. Sal y vuelve a entrar:

```bash
# Dentro de Claude Code: /exit
# Luego, desde la terminal:
claude
```

### 2d. Verificar la conexión

```bash
claude mcp list
```

**Salida esperada:**
```
filesystem: npx -y @modelcontextprotocol/server-filesystem ./data - ✓ Connected
```

Si dice `✗ Failed to connect`, revisa:
1. ¿Node está instalado? (`node --version`)
2. ¿La carpeta `./data` existe? (`ls data`)
3. Ejecuta el comando a mano para ver el error: `npx -y @modelcontextprotocol/server-filesystem ./data`

### 2e. Usar el server desde un prompt

Crea un archivo de prueba y pídele a Claude que lo lea **usando la herramienta MCP**:

```bash
echo "producto,region,unidades
Laptop Pro 14,Norte,3
Mouse Inalambrico,Sur,25" > data/ventas_demo.csv
```

En tu sesión de Claude Code, escribe:

```
Usando las herramientas MCP de filesystem (no la herramienta Read),
lista los archivos en data/ y muéstrame el contenido de ventas_demo.csv
```

Claude debe invocar `mcp__filesystem__list_directory` y `mcp__filesystem__read_text_file`.

**Verificación:** en la traza de herramientas verás nombres que empiezan con `mcp__filesystem__`. Ese prefijo (`mcp__<server>__<tool>`) es cómo Claude Code nombra toda herramienta MCP.

---

## Paso 3: Añadir un Segundo Server con Credenciales (Postgres)

Ahora el caso realista: un server que necesita secretos. **Nunca** pongas la credencial dentro de `.mcp.json` (se versiona en git); usa variables de entorno.

### 3a. Crear el archivo de variables de entorno

```bash
touch .env
```

Contenido de `.env`:

```bash
DATABASE_URL=postgresql://usuario:password@localhost:5432/mi_bd
SLACK_BOT_TOKEN=xoxb-tu-token-aqui
SLACK_TEAM_ID=T01234567
```

### 3b. Protegerlo con .gitignore

```bash
touch .gitignore
```

Añade estas líneas a `.gitignore`:

```
.env
.claude/settings.local.json
.claude/logs/
output/
```

**Verificación:**
```bash
git check-ignore -v .env
# Esperado: .gitignore:1:.env    .env
```

### 3c. Añadir el server al .mcp.json

Edita `.mcp.json` y déjalo así:

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
      "env": {
        "DATABASE_URL": "${DATABASE_URL}"
      }
    },
    "slack": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-slack"],
      "env": {
        "SLACK_BOT_TOKEN": "${SLACK_BOT_TOKEN}",
        "SLACK_TEAM_ID": "${SLACK_TEAM_ID}"
      }
    }
  }
}
```

**Cómo funciona `${VARIABLE}`:** Claude Code expande esas referencias desde el entorno de tu shell al lanzar el server. El secreto real nunca queda escrito en el archivo versionado.

### 3d. Verificar

```bash
jq . .mcp.json          # ¿JSON válido?
# Reinicia Claude Code y luego:
claude mcp list
```

Si no tienes una base Postgres a mano, `postgres` aparecerá como `✗ Failed to connect`. **Eso es esperado y no bloquea el ejercicio** — `filesystem` seguirá funcionando. El objetivo aquí es entender la estructura de configuración y el manejo de secretos.

> **Nota sobre paquetes:** los servers de referencia viven bajo el scope `@modelcontextprotocol/`. `server-filesystem` es el más estable y el que usamos para la práctica; `server-postgres` y `server-slack` son ejemplos ilustrativos de la misma forma de configuración. Para servicios propios, lo normal es escribir tu propio server (Paso 4).

---

## Paso 4: MCP Server Custom para tu API

Ahora construimos un server desde cero. Este es el patrón que usarás para exponer tu API interna a Claude.

### 4a. Crear la estructura

```bash
mkdir -p .claude/mcp-servers/analytics-api
cd .claude/mcp-servers/analytics-api
```

### 4b. Inicializar el paquete Node

```bash
npm init -y
```

### 4c. Configurar el paquete como ES module

Edita `.claude/mcp-servers/analytics-api/package.json` y añade la línea `"type": "module"`:

```json
{
  "name": "analytics-api",
  "version": "1.0.0",
  "type": "module",
  "main": "index.js"
}
```

> Sin `"type": "module"` fallará el `import` con `SyntaxError: Cannot use import statement outside a module`.

### 4d. Instalar el SDK

```bash
npm install @modelcontextprotocol/sdk
```

**Verificación:**
```bash
ls node_modules/@modelcontextprotocol/sdk
# Esperado: package.json, dist/, ...
```

### 4e. Crear el archivo del server

```bash
touch index.js
```

Contenido completo de `.claude/mcp-servers/analytics-api/index.js`:

```javascript
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  ListToolsRequestSchema,
  CallToolRequestSchema,
  ListResourcesRequestSchema,
  ReadResourceRequestSchema
} from "@modelcontextprotocol/sdk/types.js";

const server = new Server(
  { name: "analytics-api", version: "1.0.0" },
  { capabilities: { tools: {}, resources: {} } }
);

// ---------- 1. Declarar las herramientas ----------
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "get_metrics",
      description: "Obtiene métricas de negocio para un período",
      inputSchema: {
        type: "object",
        properties: {
          metric_name: { type: "string", description: "gmv, conversion_rate, churn_rate" },
          start_date:  { type: "string", description: "Fecha inicio (YYYY-MM-DD)" },
          end_date:    { type: "string", description: "Fecha fin (YYYY-MM-DD)" }
        },
        required: ["metric_name", "start_date", "end_date"]
      }
    },
    {
      name: "run_analysis",
      description: "Ejecuta un análisis predefinido",
      inputSchema: {
        type: "object",
        properties: {
          analysis_type: { type: "string", enum: ["cohort", "funnel", "retention", "segmentation"] },
          params: { type: "object" }
        },
        required: ["analysis_type"]
      }
    }
  ]
}));

// ---------- 2. Implementar las herramientas ----------
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  if (name === "get_metrics") {
    // MODO DEMO: sin API real, devolvemos datos simulados.
    // En producción: const r = await fetch(`${process.env.ANALYTICS_API_URL}/metrics/...`)
    const data = {
      metric: args.metric_name,
      period: `${args.start_date} → ${args.end_date}`,
      value: 15258.40,
      delta_vs_previous: "+12.3%"
    };
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }

  if (name === "run_analysis") {
    const data = { analysis: args.analysis_type, status: "completed", segments: 4 };
    return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
  }

  throw new Error(`Herramienta desconocida: ${name}`);
});

// ---------- 3. Exponer resources (contexto dinámico) ----------
server.setRequestHandler(ListResourcesRequestSchema, async () => ({
  resources: [
    {
      uri: "analytics://metrics-catalog",
      name: "Metrics Catalog",
      description: "Catálogo de métricas disponibles",
      mimeType: "application/json"
    }
  ]
}));

server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
  const { uri } = request.params;
  if (uri === "analytics://metrics-catalog") {
    const catalog = {
      metrics: [
        { name: "gmv", unit: "USD", grain: "daily" },
        { name: "conversion_rate", unit: "%", grain: "daily" },
        { name: "churn_rate", unit: "%", grain: "monthly" }
      ]
    };
    return {
      contents: [{ uri, mimeType: "application/json", text: JSON.stringify(catalog, null, 2) }]
    };
  }
  throw new Error(`Resource desconocido: ${uri}`);
});

// ---------- 4. Arrancar ----------
const transport = new StdioServerTransport();
await server.connect(transport);
```

### 4f. Probar el server aisladamente (antes de conectarlo)

Un MCP server con transport stdio habla JSON-RPC por stdin/stdout. Puedes probarlo sin Claude:

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | node index.js
```

**Salida esperada:** una línea JSON que incluye `"name":"get_metrics"` y `"name":"run_analysis"`.

Si ves un error, corrígelo **aquí** — depurar el server dentro de Claude Code es mucho más difícil.

### 4g. Registrar el server custom

```bash
# Volver a la raíz del proyecto
cd ../../..
pwd   # Confirma que estás en la raíz
```

Añade el bloque a `.mcp.json` (queda junto a los anteriores):

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "./data"]
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

### 4h. Verificar de punta a punta

```bash
# Reinicia Claude Code, luego:
claude mcp list
# Esperado: analytics: node .claude/mcp-servers/analytics-api/index.js - ✓ Connected
```

En la sesión, prueba:

```
¿Qué métricas tenemos disponibles en el catálogo de analytics?
Después dame el GMV del 2024-01-01 al 2024-01-31.
```

Claude leerá el resource `analytics://metrics-catalog` y luego llamará a `mcp__analytics__get_metrics`.

---

## Paso 5: Controlar Permisos de las Herramientas MCP

Las herramientas MCP entran al mismo sistema de permisos del Tema 2. Su nombre canónico es `mcp__<server>__<tool>`.

### 5a. Editar settings.json

Abre `.claude/settings.json` y **fusiona** este bloque dentro de la clave `permissions` que ya existe:

```json
{
  "permissions": {
    "allow": [
      "mcp__filesystem__read_text_file",
      "mcp__filesystem__list_directory",
      "mcp__analytics__get_metrics"
    ],
    "deny": [
      "mcp__filesystem__write_file",
      "mcp__postgres__query"
    ]
  }
}
```

### 5b. Verificar

```bash
jq '.permissions' .claude/settings.json
```

Ahora pídele a Claude que escriba un archivo vía MCP filesystem: debe ser bloqueado por el `deny`.

---

## Paso 6: Skill que Orquesta Varias Herramientas MCP

### 6a. Crear la estructura del skill

```bash
mkdir -p .claude/skills/weekly-report
touch .claude/skills/weekly-report/SKILL.md
```

### 6b. Contenido de `.claude/skills/weekly-report/SKILL.md`

```markdown
---
name: weekly-report
description: Genera el reporte semanal de métricas combinando MCP de analytics y filesystem
---

# Weekly Report Skill

## Proceso

1. **Leer el catálogo de métricas**

   Lee el resource `analytics://metrics-catalog` para saber qué métricas existen
   y con qué granularidad. No inventes nombres de métricas.

2. **Obtener métricas de la semana**

   Usa la herramienta MCP `get_metrics` una vez por cada métrica:
   - gmv
   - conversion_rate
   - churn_rate

   Rango: últimos 7 días.

3. **Comparar con la semana anterior**

   Repite `get_metrics` con el rango de hace 14 a 7 días y calcula el delta
   porcentual de cada métrica.

4. **Crear el reporte**

   Genera `output/weekly_report_<YYYY-MM-DD>.md` con:
   - Resumen ejecutivo (3 líneas máximo)
   - Tabla de métricas clave con su delta
   - Insights y recomendaciones accionables

5. **Notificar (si el MCP de Slack está conectado)**

   Usa `slack_send_message` al canal #weekly-metrics con el resumen ejecutivo
   y la ruta del reporte. Si el server no está disponible, omite este paso
   e indícalo en el output.

## Manejo de errores

- Si `get_metrics` falla para una métrica, continúa con las demás y marca esa fila como "no disponible".
- Nunca inventes valores: si no hay dato, dilo explícitamente.
```

### 6c. Ejecutar y verificar

```
/weekly-report
```

**Verificación:**
```bash
ls -la output/
# Esperado: weekly_report_<fecha>.md
cat output/weekly_report_*.md
```

---

## Verificación Final del Ejercicio

Ejecuta esta secuencia completa. Los 4 comandos deben pasar:

```bash
jq . .mcp.json > /dev/null && echo "1. OK - .mcp.json válido"
git check-ignore .env > /dev/null && echo "2. OK - .env ignorado por git"
node .claude/mcp-servers/analytics-api/index.js < /dev/null; echo "3. OK - server arranca"
claude mcp list
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
│ MCP ← ESTE TEMA     │ INTEGRACIÓN con servicios ext.  │
│ CLAUDE.md           │ Memoria + contexto del proyecto │
└─────────────────────┴──────────────────────────────────┘
```

- **Tema 2 (settings.json):** las tools MCP se permiten/deniegan como cualquier otra
- **Tema 3 (Skills):** un skill puede orquestar múltiples MCP tools (Paso 6)
- **Tema 7-8 (Agents):** un subagent puede declarar tools MCP en su frontmatter
- **Tema 4-5 (Hooks):** un `PreToolUse` con matcher `mcp__.*` valida toda llamada MCP

## Checklist de Finalización

- [ ] `node --version` ≥ 18 verificado
- [ ] `.mcp.json` creado y validado con `jq`
- [ ] Server `filesystem` conectado (`claude mcp list` muestra ✓)
- [ ] Herramienta `mcp__filesystem__read_text_file` usada desde un prompt
- [ ] `.env` creado y protegido en `.gitignore`
- [ ] Servers con credenciales declarados con `${VARIABLE}` (no secretos en claro)
- [ ] Carpeta `.claude/mcp-servers/analytics-api/` con `package.json` (`"type": "module"`)
- [ ] SDK instalado y `index.js` responde a `tools/list` por stdin
- [ ] Server custom `analytics` conectado y usado desde un prompt
- [ ] Permisos `mcp__*` configurados en `.claude/settings.json`
- [ ] Skill `weekly-report` creado y ejecutado, con reporte en `output/`

## Recursos Adicionales

- [MCP Specification](https://modelcontextprotocol.io)
- [MCP en Claude Code](https://code.claude.com/docs/en/mcp)
- [Servers de referencia](https://github.com/modelcontextprotocol/servers)

## Tip Avanzado

Implementa **rate limiting** en tu MCP server para evitar abusos. Añade esto antes del handler de `CallToolRequestSchema` en `index.js`:

```javascript
const rateLimiter = new Map();

function checkRateLimit(toolName, maxPerMinute = 10) {
  const key = `${toolName}:${Math.floor(Date.now() / 60000)}`;
  const count = rateLimiter.get(key) || 0;
  if (count >= maxPerMinute) {
    throw new Error(`Rate limit excedido para ${toolName}`);
  }
  rateLimiter.set(key, count + 1);
}

// Y como primera línea del handler:
// checkRateLimit(request.params.name);
```

Pruébalo pidiéndole a Claude 12 llamadas seguidas a `get_metrics`: las dos últimas deben fallar con el error de rate limit.
