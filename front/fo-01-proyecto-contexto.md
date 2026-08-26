# Tu Espacio de Trabajo: Proyecto e Instrucciones

**Ejercicio FO-1 - 15 minutos**

*Espeja el Tema 1 del track técnico (CLAUDE.md)*

---

## Objetivo

Crear un proyecto de Cowork sobre una carpeta real y darle a Claude el contexto de negocio que va a usar en **todas** las tareas que corras ahí, sin repetirlo nunca.

## Contexto

Cuando abres una conversación en blanco, Claude no sabe quién eres, con qué datos trabajas ni qué significa "GMV" en tu empresa. Se lo explicas, resuelve, y a la siguiente conversación lo has perdido todo.

Un **proyecto** de Cowork resuelve eso: es un espacio de trabajo con su propia carpeta, sus instrucciones y su memoria. Lo que escribas en las instrucciones se aplica a cada tarea del proyecto, siempre, sin que lo pidas.

El equipo técnico hace exactamente esto con un archivo llamado `CLAUDE.md`. Es la misma idea con otra puerta de entrada.

## Conceptos Clave

- **Proyecto:** espacio de trabajo con carpeta, instrucciones y memoria propias
- **Instrucciones:** el contexto y las reglas que Claude lee antes de cada tarea del proyecto
- **Contexto:** la carpeta local (y opcionalmente enlaces o archivos) que el proyecto puede ver
- **Memoria:** lo que Claude aprende en un proyecto y reutiliza en las siguientes tareas *del mismo proyecto*

---

## Paso 1: Preparar la Carpeta

Antes de tocar Cowork, ten una carpeta dedicada. **No apuntes el proyecto a tu carpeta de usuario ni a todo el disco** — dale exactamente lo que necesita ver.

El equipo técnico te entrega una carpeta con esta forma:

```
ventas-fo/
├── data/
│   ├── ventas_2024.csv          12 filas — el dataset principal
│   ├── ventas_2024_dirty.csv    17 filas — la versión sucia (la usarás en FO-5)
│   └── ventas_demo.csv          3 filas  — mínimo, para pruebas rápidas
└── output/                      vacía, aquí van tus reportes
```

Cópiala a un sitio estable de tu equipo (no a Descargas). La ruta va a vivir en el proyecto.

**Verificación:** abre la carpeta y confirma que `data/ventas_2024.csv` existe y tiene 12 filas de datos más el encabezado.

---

## Paso 2: Crear el Proyecto en Cowork

En la app de escritorio de Claude, pestaña **Cowork**:

1. Crea un proyecto nuevo.
2. Elige **usar una carpeta existente** y selecciona `ventas-fo/`.
3. Ponle un nombre reconocible: `Ventas — Reporte Semanal`.

A partir de aquí, toda tarea que lances dentro del proyecto ve esa carpeta.

**Verificación:** lanza una tarea y escribe `¿qué archivos hay en data/?`. Debe listarte los tres CSV sin que le des la ruta completa.

---

## Paso 3: Escribir las Instrucciones — Contexto de Negocio

Aquí está el 80% del valor del ejercicio. En las **Instrucciones** del proyecto, pega y adapta esto:

```markdown
## Qué es este proyecto

Análisis de ventas para el equipo de Business Intelligence. De aquí salen el
reporte semanal de métricas y las respuestas rápidas que pide la dirección.

## Quién lo usa

- Analistas: generan el reporte semanal
- Dirección comercial: consulta métricas puntuales, no quiere tecnicismos
- Equipo de datos: mantiene las fuentes

## Métricas clave y qué significan aquí

- GMV (Gross Merchandise Value): cantidad x precio_unitario, sumado. Es la
  métrica principal del reporte.
- Ticket medio: GMV dividido entre número de transacciones
- Mix por categoría: peso de Electronica / Accesorios / Mobiliario sobre el GMV
- Cobertura por región: Norte, Sur, Centro

## Fuentes de datos

- data/ventas_2024.csv — transacciones limpias, enero 2024
- data/ventas_2024_dirty.csv — export crudo, con defectos conocidos
- Todo lo generado va a output/

## Reglas de trabajo

- NUNCA inventes una cifra. Si un dato falta, dilo explícitamente y sigue.
- Si descartas filas de un cálculo, di cuántas y por qué.
- Marca siempre qué es dato y qué es estimación tuya.
- No muevas ni borres archivos de data/. Escribe solo en output/.
```

> **Por qué funciona:** las tres primeras secciones le dan el *porqué*; las dos últimas le dan el *cómo*. Sin el porqué, Claude te da estadística correcta pero irrelevante.

---

## Paso 4: Añadir Tus Preferencias

Debajo, en las mismas instrucciones:

```markdown
## Cómo quiero que trabajes

### Al responder
- Empieza por la conclusión, luego el detalle
- Máximo 3 líneas de resumen ejecutivo
- Cifras con separador de miles y una sola unidad (USD)

### Al entregar un documento
- Markdown en output/, nombre con fecha: reporte_YYYY-MM-DD.md
- Tabla para las métricas, prosa para los insights
- Nada de jerga técnica: esto lo lee dirección comercial

### Cuando algo no cuadra
- Párate y pregunta antes de asumir
- Si hay dos lecturas posibles de un dato, muéstrame las dos
```

**Verificación:** pídele *"dame el GMV de enero"* y comprueba que responde empezando por la cifra, no por un párrafo de contexto.

---

## Paso 5: La Prueba de Fuego

Cierra la tarea. Abre una **tarea nueva** en el mismo proyecto y escribe, tal cual:

```
¿Cuáles son las métricas clave de este proyecto y de dónde salen?
```

Debe responderte sin que le hayas explicado nada en esta tarea. Si lo hace, las instrucciones están funcionando: acabas de dejar de repetirte para siempre.

Si no lo hace, revisa que guardaste las instrucciones **del proyecto** y no las de tu perfil.

---

## Conexión con el Track Técnico

| Tú haces | El equipo técnico hace | Es lo mismo |
|---|---|---|
| Instrucciones del proyecto | `CLAUDE.md` en la raíz del repo | Contexto que se lee antes de cada tarea |
| Carpeta del proyecto | El directorio de trabajo de la sesión | Qué puede ver el agente |
| Memoria del proyecto | Historial de sesión + memoria | Lo aprendido que persiste |

La diferencia real: su `CLAUDE.md` se versiona en git y lo comparte todo el equipo. **Tu proyecto de Cowork es local y no se puede compartir**, ni en planes Team ni Enterprise. Si quieres que otra persona trabaje igual que tú, le pasas la carpeta y el texto de las instrucciones, y monta su propio proyecto.

## Checklist de Finalización

- [ ] Carpeta `ventas-fo/` en un sitio estable, con `data/` y `output/`
- [ ] Proyecto de Cowork creado sobre esa carpeta
- [ ] Instrucciones con contexto de negocio y métricas
- [ ] Instrucciones con tus preferencias de formato
- [ ] Verificado en tarea nueva: responde sin que le expliques nada

## Tip

Cuando te descubras escribiendo la misma aclaración por tercera vez en distintas tareas ("recuerda que el ticket medio excluye devoluciones"), esa frase no pertenece a la tarea: pertenece a las instrucciones del proyecto. Muévela.

Y cuando una sección de instrucciones deje de ser un *hecho* y se convierta en un *procedimiento de varios pasos*, ya no es instrucción: es una Skill. Eso es FO-3.
