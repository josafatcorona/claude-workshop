# Hooks - PreToolUse y PostToolUse

**Ejercicio 4 - 20 minutos**

---

## Objetivo

Implementar hooks que interceptan las acciones de Claude antes y después de su ejecución, permitiendo validación, logging y automatización.

## Contexto

Los Hooks son el sistema nervioso de Claude Code. Mientras los Skills son comandos que invocas, los Hooks son acciones que **siempre suceden** automáticamente. PreToolUse intercepta antes de ejecutar, PostToolUse después. Esto te da control total sobre qué puede hacer Claude y qué pasa con los resultados.

## Conceptos Clave

- **Hook:** Script que se ejecuta automáticamente en respuesta a eventos de Claude Code
- **PreToolUse:** Se ejecuta ANTES de que Claude use una herramienta (puede bloquear)
- **PostToolUse:** Se ejecuta DESPUÉS de usar una herramienta (para logging, notificaciones)
- **Exit Codes:** 0 = permitir, 2 = bloquear (stderr se muestra a Claude), otros = error no bloqueante

---

## Paso 1: Estructura de Hooks en settings.json

Los hooks se definen en `.claude/settings.json` con tres niveles de anidación: evento → lista de matchers → lista de hooks a ejecutar. **El hook no recibe el input por variables de entorno como `$TOOL_INPUT`** — recibe un JSON completo por **stdin** que debe parsear (por ejemplo con `jq`):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/validate-bash.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/log-action.sh"
          }
        ]
      }
    ]
  }
}
```

**Payload que recibe el hook por stdin (PreToolUse):**
```json
{
  "session_id": "abc123",
  "cwd": "/ruta/al/proyecto",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": { "command": "ls -la" }
}
```

`PostToolUse` recibe los mismos campos más `tool_response` con el resultado de la herramienta (no `tool_output`, aunque el efecto es el mismo: el resultado ya ejecutado).

**`${CLAUDE_PROJECT_DIR}`** es una variable de entorno real que Claude Code expone con la ruta absoluta del proyecto — úsala en vez de rutas relativas para que el hook funcione sin importar desde dónde se invoque `claude`.

---

## Paso 2: Crear Hook de Validación de Bash

Previene comandos peligrosos antes de ejecutarse.

```bash
mkdir -p .claude/hooks
touch .claude/hooks/validate-bash.sh
chmod +x .claude/hooks/validate-bash.sh
```

Contenido del script:

```bash
#!/bin/bash
# .claude/hooks/validate-bash.sh
# Valida comandos Bash antes de ejecución
# Claude Code invoca este script con el JSON del evento por STDIN, no por argumentos

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Lista de patrones peligrosos
DANGEROUS_PATTERNS=(
    "rm -rf /"
    "rm -rf ~"
    "rm -rf \$HOME"
    "> /dev/sda"
    "mkfs"
    "dd if="
    ":(){:|:&};:"
    "chmod -R 777 /"
    "wget.*| ?bash"
    "curl.*| ?bash"
)

# Verificar cada patrón
for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qE "$pattern"; then
        echo "BLOCKED: Comando peligroso detectado: $pattern"
        exit 2  # Exit code 2 = bloquear
    fi
done

# Verificar comandos de producción en desarrollo
if [[ "$ENV" == "development" ]]; then
    PROD_PATTERNS=(
        "psql.*prod"
        "mysql.*prod"
        "aws.*--profile prod"
    )
    
    for pattern in "${PROD_PATTERNS[@]}"; do
        if echo "$COMMAND" | grep -qiE "$pattern"; then
            echo "BLOCKED: Acceso a producción bloqueado en desarrollo"
            exit 2
        fi
    done
fi

# Comando permitido
exit 0
```

**Verificación:**
```bash
# Debe pasar
echo '{"tool_input": {"command": "ls -la"}}' | .claude/hooks/validate-bash.sh
echo $?  # Debe ser 0

# Debe bloquear
echo '{"tool_input": {"command": "rm -rf /"}}' | .claude/hooks/validate-bash.sh
echo $?  # Debe ser 2
```

---

## Paso 3: Hook de Validación de Escritura

Previene escritura en archivos sensibles.

```bash
touch .claude/hooks/validate-write.sh
chmod +x .claude/hooks/validate-write.sh
```

```bash
#!/bin/bash
# .claude/hooks/validate-write.sh
# Valida escrituras de archivos (JSON del evento llega por STDIN)

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')

# Archivos protegidos
PROTECTED_FILES=(
    ".env"
    ".env.local"
    ".env.production"
    "credentials"
    "secrets"
    "*.pem"
    "*.key"
    "id_rsa"
)

# Verificar archivos protegidos
for pattern in "${PROTECTED_FILES[@]}"; do
    if [[ "$FILE_PATH" == *"$pattern"* ]]; then
        echo "BLOCKED: No se permite escribir en archivos sensibles: $FILE_PATH"
        exit 2
    fi
done

# Verificar que no se escriban secretos
SECRET_PATTERNS=(
    "password\s*=\s*['\"][^'\"]+['\"]"
    "api_key\s*=\s*['\"][^'\"]+['\"]"
    "secret\s*=\s*['\"][^'\"]+['\"]"
    "AWS_SECRET"
    "PRIVATE_KEY"
)

for pattern in "${SECRET_PATTERNS[@]}"; do
    if echo "$CONTENT" | grep -qiE "$pattern"; then
        echo "BLOCKED: Posible secreto detectado en contenido"
        exit 2
    fi
done

exit 0
```

---

## Paso 4: Hook de Logging PostToolUse

Registra todas las acciones para auditoría.

```bash
touch .claude/hooks/log-action.sh
chmod +x .claude/hooks/log-action.sh
```

```bash
#!/bin/bash
# .claude/hooks/log-action.sh
# Log de todas las acciones de Claude (JSON del evento llega por STDIN)

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')
LOG_FILE=".claude/logs/actions.jsonl"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Crear directorio de logs si no existe
mkdir -p .claude/logs

# Crear entrada de log
LOG_ENTRY=$(jq -n \
    --arg ts "$TIMESTAMP" \
    --arg tool "$TOOL_NAME" \
    --argjson input "$TOOL_INPUT" \
    '{timestamp: $ts, tool: $tool, input: $input}'
)

# Append al log
echo "$LOG_ENTRY" >> "$LOG_FILE"

# Log a stderr para debugging (stdout de PostToolUse no vuelve a Claude)
echo "[LOG] $TIMESTAMP - $TOOL_NAME executed" >&2

exit 0
```

---

## Paso 5: Configuración Completa

Actualiza settings.json con todos los hooks:

```json
{
  "permissions": {
    "allow": ["Read", "Write(src/**)", "Bash(python:*)"]
  },
  "hooks": {
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
    ]
  }
}
```

**⚠️ Recuerda (Tema 2):** el bloque de arriba es un ejemplo abreviado — el `permissions.allow` mostrado no reemplaza el que ya configuraste en el Tema 2, y el `hooks` debe fusionarse con lo que ya exista en tu `settings.json` (no lo sobrescribas). Si ya activaste la regla `"deny": ["Write(.claude/settings.json)"]`, pídele a Claude que use **Edit** para aplicar este cambio — `Write` sobre este archivo específico fallará a propósito.

**Verificación:**
```bash
# Ver logs después de algunas acciones
tail -f .claude/logs/actions.jsonl
```

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

- **Tema 1 (CLAUDE.md):** Hooks refuerzan las reglas definidas en CLAUDE.md
- **Tema 2 (settings.json):** Los hooks se configuran en settings.json
- **Tema 3 (Skills):** Los hooks aplican a todas las acciones, incluyendo las de skills

## Checklist de Finalización

- [ ] Directorio .claude/hooks/ creado
- [ ] Hook validate-bash.sh funcional
- [ ] Hook validate-write.sh funcional
- [ ] Hook log-action.sh registrando acciones
- [ ] settings.json actualizado con hooks
- [ ] Probado que comandos peligrosos se bloquean

## Recursos Adicionales

- [Guía de Hooks](https://code.claude.com/docs/en/hooks)

## Tip Avanzado

Además del exit code 2, un hook `PreToolUse` puede responder con JSON estructurado en stdout (con exit 0) para decidir con más matiz que solo "bloquear o no":

```bash
#!/bin/bash
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if echo "$COMMAND" | grep -q "sudo "; then
    jq -n '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: "sudo no está permitido en este proyecto"
      }
    }'
    exit 0
fi

exit 0
```

`permissionDecision` acepta `"allow"`, `"deny"`, `"ask"` o `"defer"` — más expresivo que devolver solo un exit code, y te permite dar una razón que Claude puede mostrarle al usuario.
