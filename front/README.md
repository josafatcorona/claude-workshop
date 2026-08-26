# Track Front Office — Claude en Chat y Cowork

Versión del taller para equipos que **no van a usar Claude Code**. Mismo recorrido conceptual, mismo dataset y mismo entregable final que el curso técnico, pero íntegramente desde las pestañas **Chat** y **Cowork** de la app de escritorio.

## Para quién es

Perfiles de negocio que quieren usar Claude de forma seria —contexto persistente, procedimientos guardados, trabajo delegado, integración con sus herramientas— sin tocar archivos de configuración ni línea de comandos.

No es una versión reducida del curso técnico: es la **cara de consumo** del mismo sistema. Lo que el equipo técnico construye en el track principal es, literalmente, lo que este equipo usa aquí.

## Estructura

| # | Título | Duración | Espeja | Archivo |
|---|--------|----------|--------|---------|
| FO-1 | Tu Espacio de Trabajo: Proyecto e Instrucciones | 15 min | Tema 1 | [fo-01-proyecto-contexto.md](fo-01-proyecto-contexto.md) |
| FO-2 | Alcance, Permisos y Elección de Modelo | 15 min | Temas 2 y 6 | [fo-02-alcance-permisos-modelo.md](fo-02-alcance-permisos-modelo.md) |
| FO-3 | Tu Primera Skill Publicada | 20 min | Tema 3 | [fo-03-primera-skill.md](fo-03-primera-skill.md) |
| FO-4 | Guardarraíles: Instrucción vs. Garantía | 15 min | Temas 4 y 5 | [fo-04-instruccion-vs-garantia.md](fo-04-instruccion-vs-garantia.md) |
| FO-5 | Encargar Trabajo Largo | 20 min | Temas 7 y 8 | [fo-05-encargar-trabajo-largo.md](fo-05-encargar-trabajo-largo.md) |
| FO-6 | Connectors: Conectar Claude a tus Herramientas | 20 min | Tema 9 | [fo-06-connectors.md](fo-06-connectors.md) |
| FO-7 | El Puente con el Equipo Técnico | 15 min | Cierre conjunto | [fo-07-puente-equipo-tecnico.md](fo-07-puente-equipo-tecnico.md) |

**Total: ~2 horas.** FO-7 se imparte en conjunto con el track técnico.

También disponible como **[HTML interactivo](curso-front-office.html)** — misma navegación, búsqueda, copy-to-clipboard y seguimiento de progreso que el curso principal. Ábrelo en el navegador; no necesita servidor.

## Regla de Oro — versión Front Office

```
┌─────────────────────────────────────────────────────────┐
│          REGLA DE ORO — VERSIÓN FRONT OFFICE            │
├──────────────────────┬──────────────────────────────────┤
│ INSTRUCCIONES        │ Lo que Claude DEBE SABER siempre │
│ SKILL                │ Un procedimiento que REPITES     │
│ TAREA LARGA          │ Trabajo que se DELEGA por etapas │
│ CONNECTOR            │ INTEGRACIÓN con tus herramientas │
│ ALCANCE Y PERMISOS   │ Lo único que es GARANTÍA         │
└──────────────────────┴──────────────────────────────────┘
```

La última fila es la diferencia real con el track técnico y tiene su propio ejercicio (FO-4).

## Prerequisitos

**Del asistente:**
- App de escritorio de Claude instalada, con sesión iniciada
- Plan Pro, Max, Team o Enterprise (Cowork no está en el plan gratuito)
- La carpeta `ventas-fo/` con los datos, copiada a un sitio estable

**De la organización — verificar ANTES del taller:**
- *Organization settings → Skills*: los interruptores **Skills** y **Code execution and file creation** deben estar activados, o nadie podrá subir la skill de FO-3
- *Organization settings → Connectors*: al menos un connector de lectura disponible para FO-6
- Confirmar que los asistentes ven el menú **Customize** en la barra lateral

## Qué debe preparar el equipo técnico

Esto es lo que convierte los dos tracks en un solo sistema. Sin ello, FO-3 y FO-6 se quedan a medias:

1. **La carpeta de datos.** Ejecutar `./generar-datos-muestra.sh <destino>` desde la raíz del curso y repartir el resultado como `ventas-fo/`. Los conteos de FO-3 y FO-5 dependen de que sea exactamente ese dataset.
2. **Las skills publicables.** Están en [`skills-publicables/`](skills-publicables/), ya con el encabezado válido para subida a claude.ai (solo `name` y `description`). Súbelas desde *Organization settings → Skills* para que lleguen a todo el mundo activadas, o déjalas para que cada asistente suba la suya en FO-3.
3. **Un connector de lectura** añadido al equipo desde *Organization settings → Connectors*.
4. **La demo de FO-7:** el hook `validate-bash.sh` del Tema 4 del track técnico, funcionando y listo para enseñar en vivo.

## Tres cosas que hay que saber antes de diseñar sesiones

**Los proyectos de Cowork son locales y no se comparten**, ni en Team ni en Enterprise. No puedes repartir un espacio de trabajo montado: cada asistente crea el suyo en FO-1. Lo que sí se reparte es la carpeta y el texto de las instrucciones.

**El encabezado de una skill subida a claude.ai admite solo seis campos** (`name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools`) y cualquier otro **hace fallar la subida**, no se ignora. Las skills del track técnico usan `arguments:` y por eso no sirven tal cual: las de `skills-publicables/` ya están convertidas.

**Los plugins provisionados por la organización no llegan a Cowork ni a Chat**, solo a Claude Code. El canal correcto para este equipo son *Skills* y *Connectors*.

## Correspondencia con el curso técnico

| Track técnico | Track front office | Qué cambia |
|---|---|---|
| `CLAUDE.md` | Instrucciones del proyecto | Dónde vive, no qué hace |
| `.claude/settings.json` | Alcance de carpeta + modo de permiso | Menos granular |
| `.claude/skills/*/SKILL.md` | Skill en Customize | Encabezado restringido, sin ejecución de shell |
| Hooks | *(sin equivalente)* | Es el contenido de FO-4 |
| `.claude/agents/*.md` | Encargo por etapas | Claude coordina; tú no defines los agentes |
| `.mcp.json` | Connectors | Instalación gráfica, OAuth por usuario |

## Entregable final

Ambos tracks terminan produciendo **el mismo reporte semanal sobre los mismos datos**, por caminos distintos. Ese es el cierre natural para una sesión conjunta: poner los dos resultados uno al lado del otro.
