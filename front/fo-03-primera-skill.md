# Tu Primera Skill Publicada

**Ejercicio FO-3 - 20 minutos**

*Espeja el Tema 3 del track técnico (Tu Primer Skill)*

---

## Objetivo

Escribir un procedimiento que repites a mano, publicarlo como Skill en tu cuenta, e invocarlo con `/` desde Cowork y desde Chat.

## Contexto

Una **Skill** es un procedimiento guardado. En vez de reescribir "analiza este CSV, dime dimensiones, nulos, top productos, y avísame si algo huele mal" cada lunes, lo escribes una vez y lo invocas con `/analizar-ventas`.

Lo importante: **es exactamente el mismo formato que usa el equipo técnico.** Una Skill escrita para Claude Code funciona en Cowork y al revés. Lo único que cambia es dónde vive: la suya en el repositorio, la tuya en tu cuenta de claude.ai.

## Conceptos Clave

- **SKILL.md:** un archivo Markdown con dos partes — encabezado y procedimiento
- **Encabezado (frontmatter):** el bloque entre `---` con el nombre y la descripción
- **`description`:** la línea que decide **cuándo se dispara** la skill. Es lo que más falla
- **Customize → Skills:** donde se suben y se activan para tu cuenta

---

## Paso 1: La Anatomía, y la Regla que Rompe Todo

Un SKILL.md tiene esta forma:

```markdown
---
name: nombre-en-minusculas-con-guiones
description: Qué hace y cuándo debe usarse.
---

# Título

Las instrucciones, paso a paso, en prosa.
```

> ### ⚠️ Solo seis campos, y el error es duro
>
> Al subir una skill a tu cuenta, el encabezado admite **exactamente** estos campos:
> `name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools`.
>
> Cualquier otro campo **no se ignora: la subida falla.** Si copias un ejemplo de
> internet o del track técnico que trae `arguments:`, `triggers:`, `model:` o
> `tools:`, quítalos antes de subir.
>
> En la práctica, con `name` y `description` tienes de sobra.

Dos reglas más del cuerpo, para que la skill se comporte igual en Cowork y en Chat:

- **Nada de argumentos con plantilla** (`{{file}}`, `$ARGUMENTS`). En su lugar, describe en prosa qué necesitas del usuario y qué hacer si no lo dice.
- **Nada de líneas que ejecuten comandos** (las que empiezan por `!`). En Cowork se anulan y en Chat no existen.

---

## Paso 2: Escribir `analizar-ventas`

Crea un archivo llamado `SKILL.md` con esto:

```markdown
---
name: analizar-ventas
description: Analiza un archivo CSV de ventas y produce un resumen ejecutivo con métricas de negocio, calidad de datos y recomendaciones. Úsala cuando pidan analizar, revisar, resumir o sacar métricas de un archivo de ventas, un CSV de transacciones o un export de pedidos.
---

# Análisis de un archivo de ventas

## Qué necesitas del usuario

La ruta del archivo a analizar. Si no la dice y hay un solo CSV de ventas
en la carpeta del proyecto, usa ese y avisa de cuál elegiste. Si hay varios,
lista los candidatos y pregunta.

## 1. Reconocimiento

Abre el archivo y reporta, en una sola línea: número de filas de datos,
número de columnas y el rango de fechas que cubre.

Ojo con dos defectos frecuentes en estos exports: puede haber una línea en
blanco antes del encabezado, y puede haber espacios sobrantes alrededor de
los valores. Trátalos antes de contar.

## 2. Métricas de negocio

Calcula y presenta en una tabla:

- GMV total (cantidad x precio_unitario, sumado)
- Número de transacciones
- Ticket medio
- GMV por categoría, con su peso porcentual
- GMV por región, con su peso porcentual
- Los 3 productos con mayor GMV

## 3. Calidad de los datos

Revisa y reporta solo lo que encuentres, sin rellenar con obviedades:

- Celdas vacías, indicando columna y cuántas
- Filas duplicadas exactas
- Fechas en formatos distintos dentro de la misma columna
- Columnas con un único valor en todas las filas

Por cada problema, di si afecta a alguna de las métricas del punto 2 y cómo.

## 4. Decisiones que tomaste

Si excluiste alguna fila de algún cálculo, di cuántas, de qué cálculo y por qué.
Nunca imputes un valor faltante sin decirlo. Si un dato no se puede recuperar,
la respuesta correcta es decir que falta, no inventar un promedio.

## 5. Salida

Termina con:

- Tres líneas de resumen ejecutivo, sin jerga
- La tabla de métricas
- La lista de problemas encontrados, si los hay
- Máximo tres recomendaciones, ordenadas por impacto
```

> **Nota:** el track técnico escribe esta misma skill con un bloque de código Python dentro. La tuya está en prosa a propósito: Claude decide con qué herramienta calcular según dónde la invoques. El resultado es el mismo y funciona en las dos pestañas.

---

## Paso 3: Publicarla

En la app de escritorio, barra lateral → **Customize** → **Skills** → subir la skill.

Si tu organización ya te provisionó skills, las verás ahí mismo, activadas por defecto. Las tuyas conviven con ellas.

**Verificación:** la skill aparece en la lista y está activada.

> Si la subida falla, el 95% de las veces es un campo de más en el encabezado. Revisa la caja del Paso 1.

---

## Paso 4: Usarla

En una tarea de Cowork dentro de tu proyecto, escribe `/` y elige `analizar-ventas`. Añade el archivo:

```
/analizar-ventas  sobre data/ventas_2024.csv
```

**Lo que debe pasar** con el dataset del curso:

| Comprobación | Valor esperado |
|---|---|
| Filas de datos | 12 |
| Columnas | 6 |
| Celdas vacías | 1, en `cantidad`, fila del 2024-01-15 |
| Decisión declarada | Debe decir qué hizo con esa fila y por qué |

Ese último punto es el que importa. Una skill que te da el GMV sin avisarte de que descartó una fila te está mintiendo por omisión.

**Pruébala también en Chat:** abre la pestaña Chat, invoca `/analizar-ventas` y adjunta el CSV. Debe comportarse igual. Si en Chat pierde pasos, es señal de que el cuerpo tiene algo específico de Cowork.

---

## Paso 5: Afinar la `description` — el paso que casi todos se saltan

La `description` no es documentación: **es el disparador.** Es la única parte de la skill que Claude lee siempre, y con ella decide si la usa o no.

Prueba a invocarla sin nombrarla. En una tarea nueva:

```
Échale un ojo a data/ventas_2024.csv y dime cómo va el mes
```

¿Se disparó la skill? Mira la diferencia:

| Descripción | Problema |
|---|---|
| `Analiza un CSV` | Demasiado genérica: se dispara con cualquier CSV, incluso cuando no toca |
| `Ejecuta el procedimiento estándar de análisis del equipo de BI` | No contiene ninguna palabra que el usuario vaya a escribir. No se dispara nunca |
| La del Paso 2 | Dice **qué hace** y luego **con qué frases se pide**. Ese es el patrón |

**Verificación:** ajusta la descripción hasta que se dispare con las frases con las que tú pedirías el trabajo de verdad, y no con otras.

---

## Conexión con el Track Técnico

| Tú | Equipo técnico |
|---|---|
| Skill en Customize → Skills | `.claude/skills/nombre/SKILL.md` en el repo |
| La sube cada persona a su cuenta | Se versiona en git, la tiene todo el equipo |
| Encabezado: 6 campos, error duro | Encabezado extendido: `model`, `tools`, `allowed-tools`... |
| Prosa; sin `!` ni plantillas | Puede ejecutar comandos e inyectar contexto dinámico |

**Lo importante para el taller:** cuando ellos publiquen una skill para la organización desde *Organization settings → Skills*, te aparecerá en tu Customize activada por defecto. Ese es el canal por el que te va a llegar el trabajo hecho. Los *plugins* que ellos instalen, en cambio, **no llegan a Cowork ni a Chat** — solo a Claude Code.

## Checklist de Finalización

- [ ] SKILL.md escrito con encabezado de 2 campos
- [ ] Sin `arguments`, `triggers`, plantillas ni líneas `!`
- [ ] Subida en Customize → Skills y activada
- [ ] Invocada con `/` en Cowork sobre `ventas_2024.csv`
- [ ] Resultado verificado: 12 filas, 1 celda vacía, decisión declarada
- [ ] Probada también en Chat
- [ ] `description` afinada hasta que se dispara sola

## Tip

Escribe tu primera skill a mano, como acabas de hacer. A partir de la tercera, pídele a Claude que te la redacte: *"conviérteme este procedimiento en una skill, con una description que se dispare cuando alguien pida el cierre de mes"*. Sabrás revisar lo que te dé porque ya entiendes las piezas.

Y la señal de que algo debería ser skill: **lo has escrito tres veces en tres tareas distintas.**
