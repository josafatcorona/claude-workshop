# Hooks - Lifecycle Completo (SessionStart, Stop)

**Ejercicio 5 - 15 minutos**

---

## Objetivo

Dominar el ciclo de vida completo de hooks: inicialización de sesión, pausa, reanudación y limpieza, para crear flujos de trabajo automatizados robustos.

## Qué vas a construir (y cómo sabes que terminaste)

Al final de este ejercicio tendrás 4 scripts en `.claude/hooks/` conectados en `settings.json`, y podrás demostrar que funcionan **sin depender de abrir/cerrar Claude Code de verdad** — cada paso incluye una "Verificación" que simula el evento con `echo '...json...' | script.sh` (igual que en el Tema 4).

Criterios concretos de "terminado":
1. `session-start.sh` crea un archivo `.claude/logs/session_<id>.json` con `status: "active"`.
2. `session-end.sh`, corrido después, actualiza ese mismo archivo a `status: "completed"` y añade `ended_at`.
3. `notify.sh` escribe una línea en `.claude/logs/notifications.log` al recibir un mensaje de notificación simulado.
4. `pre-prompt.sh` imprime un `WARNING` cuando el prompt simulado contiene una frase peligrosa (p. ej. `"drop database"`), y un `CONTEXT` cuando el prompt menciona análisis de datos.

Si logras los 4 puntos anteriores con los comandos de "Verificación" de cada paso, el ejercicio está resuelto — no necesitas esperar a que el evento real dispare para confirmarlo.

## Contexto

Más allá de PreToolUse y PostToolUse, Claude Code ofrece hooks de ciclo de vida que se ejecutan en momentos clave de la sesión. Estos permiten inicializar ambientes, cargar contexto, persistir estado y limpiar recursos automáticamente.

## Conceptos Clave

- **SessionStart:** Se ejecuta al iniciar (o resumir) una sesión de Claude Code
- **SessionEnd:** Se ejecuta al terminar la sesión por completo — es donde persistes estado y limpias recursos, no "SessionStop" (ese evento no existe)
- **Stop:** Se ejecuta cada vez que Claude termina de responder (una vez por turno, no una vez por sesión) — útil para un chequeo final por respuesta, no para limpieza de sesión
- **Notification:** Se ejecuta cuando Claude Code emite una notificación al usuario (p. ej. pide permiso o queda inactivo)
- **UserPromptSubmit:** Se ejecuta cuando el usuario envía un mensaje, antes de que Claude lo procese

---

## Paso 1: Hook de Inicio de Sesión

Inicializa el ambiente y carga contexto al comenzar.

```bash
touch .claude/hooks/session-start.sh
chmod +x .claude/hooks/session-start.sh
```

```bash
#!/bin/bash
# .claude/hooks/session-start.sh
# Inicialización de sesión — el JSON del evento llega por STDIN

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
LOG_DIR=".claude/logs"
SESSION_FILE="$LOG_DIR/session_$SESSION_ID.json"

# Crear directorio de logs
mkdir -p "$LOG_DIR"

# Verificar prerequisitos
check_prerequisites() {
    local missing=()
    
    # Verificar Python
    if ! command -v python &> /dev/null; then
        missing+=("python")
    fi
    
    # Verificar dependencias
    if [[ -f "requirements.txt" ]]; then
        python -c "import pkg_resources; pkg_resources.require(open('requirements.txt').readlines())" 2>/dev/null
        if [[ $? -ne 0 ]]; then
            echo "WARNING: Algunas dependencias faltan. Ejecuta: pip install -r requirements.txt"
        fi
    fi
    
    # Verificar variables de entorno requeridas
    required_vars=("DATABASE_URL" "ENV")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            echo "WARNING: Variable $var no definida"
        fi
    done
}

# Cargar estado previo si existe
load_previous_state() {
    STATE_FILE=".claude/state/current.json"
    if [[ -f "$STATE_FILE" ]]; then
        echo "INFO: Estado previo encontrado, cargando contexto..."
        cat "$STATE_FILE"
    fi
}

# Crear registro de sesión
create_session_record() {
    jq -n \
        --arg id "$SESSION_ID" \
        --arg start "$TIMESTAMP" \
        --arg cwd "$(pwd)" \
        --arg user "$(whoami)" \
        --arg branch "$(git branch --show-current 2>/dev/null || echo 'N/A')" \
        '{
            session_id: $id,
            started_at: $start,
            working_directory: $cwd,
            user: $user,
            git_branch: $branch,
            status: "active"
        }' > "$SESSION_FILE"
}

# Ejecutar inicialización
echo "=== Iniciando sesión Claude Code ==="
check_prerequisites
load_previous_state
create_session_record
echo "=== Sesión $SESSION_ID iniciada ==="

exit 0
```

**Verificación:**
```bash
# Simula el evento SessionStart con un session_id de prueba
echo '{"session_id": "test123"}' | .claude/hooks/session-start.sh

# Debe existir el archivo de sesión con status "active"
cat .claude/logs/session_test123.json
# {..., "status": "active"}
```

---

## Paso 2: Hook de Fin de Sesión

Limpia recursos y persiste estado al terminar. El evento correcto para "la sesión completa terminó" es `SessionEnd` (no existe un `SessionStop`):

```bash
touch .claude/hooks/session-end.sh
chmod +x .claude/hooks/session-end.sh
```

```bash
#!/bin/bash
# .claude/hooks/session-end.sh
# Limpieza y persistencia al terminar sesión — JSON del evento por STDIN

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
LOG_DIR=".claude/logs"
SESSION_FILE="$LOG_DIR/session_$SESSION_ID.json"

# Actualizar registro de sesión
update_session_record() {
    if [[ -f "$SESSION_FILE" ]]; then
        TMP_FILE=$(mktemp)
        jq --arg end "$TIMESTAMP" \
           '.ended_at = $end | .status = "completed"' \
           "$SESSION_FILE" > "$TMP_FILE"
        mv "$TMP_FILE" "$SESSION_FILE"
    fi
}

# Generar resumen de sesión
generate_session_summary() {
    ACTIONS_LOG="$LOG_DIR/actions.jsonl"
    if [[ -f "$ACTIONS_LOG" ]]; then
        # Un solo proceso jq para todo el fichero (ver nota tras el script)
        TOOL_LIST=$(jq -r '.tool // empty' "$ACTIONS_LOG" 2>/dev/null)
        TOTAL_ACTIONS=$(printf '%s\n' "$TOOL_LIST" | grep -c .)
        TOOLS_USED=$(printf '%s\n' "$TOOL_LIST" | sort | uniq -c | sort -rn)
        
        echo "=== Resumen de Sesión ==="
        echo "Total de acciones: $TOTAL_ACTIONS"
        echo "Herramientas usadas:"
        echo "$TOOLS_USED"
    fi
}

# Limpiar archivos temporales
cleanup_temp_files() {
    find .claude/tmp -type f -mmin +60 -delete 2>/dev/null
    rm -rf .claude/cache/*.tmp 2>/dev/null
}

# Persistir estado para próxima sesión
persist_state() {
    STATE_DIR=".claude/state"
    mkdir -p "$STATE_DIR"
    
    # Guardar estado actual
    jq -n \
        --arg last_session "$SESSION_ID" \
        --arg timestamp "$TIMESTAMP" \
        --arg branch "$(git branch --show-current 2>/dev/null)" \
        '{
            last_session: $last_session,
            saved_at: $timestamp,
            git_branch: $branch
        }' > "$STATE_DIR/current.json"
}

# Ejecutar limpieza
echo "=== Finalizando sesión Claude Code ==="
update_session_record
generate_session_summary
cleanup_temp_files
persist_state
echo "=== Sesión $SESSION_ID finalizada ==="

exit 0
```

**⚠️ SessionEnd tiene prisa: si tarda, lo cancelan.** El hook corre mientras el proceso
se está cerrando. Si el proceso muere antes de que termine, Claude Code lo aborta con:

```
SessionEnd hook [.../session-end.sh] failed: Hook cancelled
```

Esto se ve sobre todo con subcomandos efímeros como `claude mcp list`, que terminan en
unos segundos. Regla práctica: **un `SessionEnd` debe medirse en milisegundos.** El error
típico es procesar el log línea a línea:

```bash
# ❌ un proceso jq por línea — 7.8s con 3k líneas, el hook no llega a terminar
while IFS= read -r line; do echo "$line" | jq -r '.tool'; done < "$ACTIONS_LOG"

# ✅ un solo proceso jq para todo el fichero — 0.02s con el mismo fichero
jq -r '.tool // empty' "$ACTIONS_LOG"
```

Mide siempre el tuyo antes de darlo por bueno:

```bash
time (echo '{"session_id": "test123"}' | .claude/hooks/session-end.sh)
```

**Verificación:**
```bash
# Reusa el mismo session_id que en el Paso 1, para actualizar el mismo archivo
echo '{"session_id": "test123"}' | .claude/hooks/session-end.sh

# Debe estar en status "completed" y tener ended_at
cat .claude/logs/session_test123.json
# {..., "status": "completed", "ended_at": "..."}

# También debió persistir estado para la próxima sesión
cat .claude/state/current.json
```

---

## Paso 3: Hook de Notificaciones

Envía alertas cuando Claude Code emite una notificación (por ejemplo, cuando necesita permiso o queda inactivo esperando input).

```bash
touch .claude/hooks/notify.sh
chmod +x .claude/hooks/notify.sh
```

```bash
#!/bin/bash
# .claude/hooks/notify.sh
# Reenvía las notificaciones de Claude Code a Slack/escritorio — JSON por STDIN

INPUT=$(cat)
MESSAGE=$(echo "$INPUT" | jq -r '.message // "Notificación de Claude Code"')

mkdir -p .claude/logs

# Notificación de escritorio (Linux)
if command -v notify-send &> /dev/null; then
    notify-send "Claude Code" "$MESSAGE"
fi

# Slack webhook (opcional)
if [[ -n "$SLACK_WEBHOOK_URL" ]]; then
    curl -s -X POST "$SLACK_WEBHOOK_URL" \
        -H 'Content-type: application/json' \
        -d "{\"text\": \"Claude Code: $MESSAGE\"}"
fi

# Log local
echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] $MESSAGE" >> .claude/logs/notifications.log

exit 0
```

**Verificación:**
```bash
echo '{"message": "Claude necesita tu permiso para continuar"}' | .claude/hooks/notify.sh

# Debe haberse registrado la línea
tail -1 .claude/logs/notifications.log
```

---

## Paso 4: Hook de Pre-Prompt

Ejecuta validaciones antes de procesar el prompt del usuario.

```bash
touch .claude/hooks/pre-prompt.sh
chmod +x .claude/hooks/pre-prompt.sh
```

```bash
#!/bin/bash
# .claude/hooks/pre-prompt.sh
# Validación y enriquecimiento de prompts — JSON del evento por STDIN

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')

# Detectar intenciones potencialmente peligrosas
dangerous_intents=(
    "delete all"
    "drop database"
    "format disk"
    "remove everything"
)

for intent in "${dangerous_intents[@]}"; do
    if echo "$PROMPT" | grep -qi "$intent"; then
        echo "WARNING: Prompt contiene intención peligrosa: $intent"
        echo "Por favor, confirma esta acción específicamente."
        # No bloqueamos, solo advertimos
    fi
done

# Enriquecer con contexto si es análisis de datos
if echo "$PROMPT" | grep -qiE "(analiza|analyze|datos|data|csv|dataframe)"; then
    echo "CONTEXT: El usuario trabaja con análisis de datos."
    echo "CONTEXT: Revisar CLAUDE.md para convenciones de análisis."
fi

exit 0
```

**Verificación:**
```bash
# Debe imprimir un WARNING
echo '{"prompt": "por favor drop database de producción"}' | .claude/hooks/pre-prompt.sh

# Debe imprimir CONTEXT (menciona análisis de datos)
echo '{"prompt": "analiza este csv de ventas"}' | .claude/hooks/pre-prompt.sh

# No debe imprimir nada especial (prompt neutro)
echo '{"prompt": "hola, ¿cómo estás?"}' | .claude/hooks/pre-prompt.sh
```

---

## Paso 5: Configuración Completa del Lifecycle

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/session-start.sh" }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/session-end.sh" }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/pre-prompt.sh" }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/validate-bash.sh" }
        ]
      },
      {
        "matcher": "Write",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/validate-write.sh" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "*",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/log-action.sh" }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/notify.sh" }
        ]
      }
    ]
  }
}
```

**⚠️ Recuerda (Tema 2):** este bloque muestra el objeto `hooks` **completo** — la fusión de los hooks del Tema 4 (`PreToolUse`, `PostToolUse`) con los de este tema (`SessionStart`, `SessionEnd`, `UserPromptSubmit`, `Notification`). Debe quedar **una sola clave `"hooks"`** en tu `settings.json` con todo adentro — no agregues un segundo bloque `"hooks": {...}` junto al que ya tenías del Tema 4, o Claude Code solo aplicará el último y perderás los hooks anteriores. Las claves `permissions` y `env` del Tema 2 no aparecen aquí porque no cambian en este paso — deben seguir intactas en el archivo, al mismo nivel que `hooks`. Si activaste `"deny": ["Write(.claude/settings.json)"]`, pide a Claude que use **Edit** para este archivo, no Write.

**Verificación del flujo completo (con Claude Code real, no simulado):**
1. Guarda `settings.json` y abre una sesión nueva de Claude Code en este proyecto → debe aparecer `.claude/logs/session_<id_real>.json` con `status: "active"` (SessionStart disparó de verdad).
2. Escribe un prompt como `"analiza este csv"` → deberías ver el `CONTEXT` de `pre-prompt.sh` antes de que Claude responda (UserPromptSubmit).
3. Pide a Claude que corra cualquier comando (p. ej. `ls`) → revisa que `.claude/logs/actions.jsonl` tenga una línea nueva (PostToolUse).
4. Termina la sesión (`/exit` o cerrando la terminal) → el mismo `session_<id_real>.json` debe pasar a `status: "completed"` (SessionEnd disparó de verdad).

Si los 4 pasos ocurren, el lifecycle completo está funcionando end-to-end, no solo en simulaciones con `echo`.

---

## Diagrama del Lifecycle

```
┌─────────────────────────────────────────────────────────┐
│                    LIFECYCLE DE SESIÓN                  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────┐                                       │
│  │ SessionStart │ → Inicializar ambiente, cargar estado│
│  └──────┬───────┘                                       │
│         │                                               │
│         ▼                                               │
│  ┌──────────────────┐                                   │
│  │ UserPromptSubmit │ → Validar/enriquecer prompt      │
│  └──────┬───────────┘                                   │
│         │                                               │
│         ▼                                               │
│  ┌─────────────┐      ┌─────────────┐                  │
│  │ PreToolUse  │ ───► │  TOOL USE   │ (Bash, Write...) │
│  └─────────────┘      └──────┬──────┘                  │
│                              │                         │
│                              ▼                         │
│                       ┌─────────────┐                  │
│                       │ PostToolUse │ → Log, validar   │
│                       └──────┬──────┘                  │
│                              │                         │
│         ◄────────────────────┘ (loop)                  │
│         │                                               │
│         ▼                                               │
│  ┌─────────────┐                                        │
│  │ SessionEnd  │ → Limpiar, persistir estado           │
│  └─────────────┘                                        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

`Stop` no aparece en este diagrama: dispara una vez por cada respuesta de Claude (no una vez por sesión), así que vive "dentro" del loop de arriba, no al final.

---

## Conexión con Ejercicios Anteriores

```
┌─────────────────────────────────────────────────────────┐
│              REGLA DE ORO: ¿QUÉ USAR?                 │
├─────────────────────┬──────────────────────────────────┤
│ SKILL               │ Cosas que el agente DEBE SABER   │
│ HOOK ← ESTE TEMA    │ Cosas que SIEMPRE SUCEDEN        │
│ SUBAGENT            │ Cosas que SE DELEGAN            │
│ MCP                 │ INTEGRACIÓN con servicios ext.  │
│ CLAUDE.md           │ Memoria + contexto del proyecto │
└─────────────────────┴──────────────────────────────────┘
```

- **Tema 4 (PreToolUse/PostToolUse):** Ahora tienes el ciclo completo
- Los hooks de lifecycle complementan la validación por herramienta

## Checklist de Finalización

- [ ] Hook session-start.sh creado y funcional
- [ ] Hook session-end.sh creado y funcional
- [ ] Hook notify.sh configurado
- [ ] Hook pre-prompt.sh implementado
- [ ] settings.json actualizado con todos los lifecycle hooks
- [ ] Probado el flujo completo inicio → uso → fin

## Recursos Adicionales

- [Hooks Reference](https://code.claude.com/docs/en/hooks.md)
- [Hooks Page](https://code.claude.com/docs/en/hooks#macos%2Flinux)

## Tip Avanzado

Combina hooks con **estado persistente** para crear flujos de trabajo que recuerdan contexto entre sesiones:

```bash
# En session-start.sh
if [[ -f ".claude/state/pending_tasks.json" ]]; then
    echo "CONTEXT: Hay tareas pendientes de la sesión anterior:"
    cat .claude/state/pending_tasks.json
fi
```

Esto permite que Claude retome trabajo donde lo dejaste.
