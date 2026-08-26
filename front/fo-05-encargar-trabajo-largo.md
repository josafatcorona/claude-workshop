# Encargar Trabajo Largo

**Ejercicio FO-5 - 20 minutos**

*Espeja los Temas 7 y 8 del track técnico (Subagents y Agent Teams)*

---

## Objetivo

Encargar un trabajo de varias etapas en una sola tarea, con criterios de aceptación por etapa, y verificar el resultado por conteos en vez de por confianza.

## Contexto

Hasta aquí has pedido cosas de un paso. Cowork está pensado para lo otro: describes un resultado, te levantas, y vuelves al trabajo terminado. Por dentro, Claude parte el encargo en tareas más pequeñas y coordina varios subagentes en paralelo.

**Tú no defines esos subagentes.** El equipo técnico sí — escriben un archivo por cada especialista, con su modelo y sus herramientas. Tú consigues casi el mismo resultado escribiendo un buen encargo. Este ejercicio va de eso: la diferencia entre pedir "límpiame esto" y encargar un trabajo.

## Conceptos Clave

- **Tarea larga:** un encargo de varias etapas que Claude ejecuta sin que le lleves de la mano
- **Etapas:** los pasos del encargo, cada uno con una entrada y una salida
- **Criterio de aceptación:** cómo se sabe que una etapa salió bien, en números
- **Verificación por conteos:** comprobar el resultado contando, no leyendo

---

## Paso 1: El Dataset Sucio

Vas a trabajar con `data/ventas_2024_dirty.csv`, que es el export crudo. Tiene defectos puestos a propósito:

```
17 filas de datos
  - 3 formatos de fecha mezclados (2024-02-01, 03/02/2024, 15-Feb-2024)
  - 2 duplicados exactos
  - 1 cantidad vacía y 1 precio_unitario vacío
  - espacios sobrantes alrededor de algunos valores
```

**Verificación:** ábrelo y localiza a ojo al menos un duplicado y los tres formatos de fecha. Necesitas saber qué hay dentro para poder juzgar el resultado.

---

## Paso 2: El Encargo Vago (para tener con qué comparar)

Antes de hacerlo bien, hazlo mal. En una tarea nueva:

```
Limpia data/ventas_2024_dirty.csv y hazme un reporte
```

Déjalo correr. Guarda el resultado. **No lo juzgues todavía** — vuelve al final del ejercicio.

---

## Paso 3: El Encargo por Etapas

Tarea nueva. Ahora el encargo de verdad:

```
Quiero un reporte de ventas a partir de data/ventas_2024_dirty.csv.
Trabájalo en cuatro etapas y no pases a la siguiente sin dejar constancia
del resultado de la anterior.

ETAPA 1 — Extracción
Lee el archivo tal cual. Cuenta las filas de datos.
Criterio: debes reportar el número exacto de filas leídas.

ETAPA 2 — Limpieza
Normaliza las fechas a formato AAAA-MM-DD, elimina duplicados exactos y
quita espacios sobrantes.
Criterio: reporta cuántas filas eliminaste y por qué motivo cada una.
Guarda el resultado en output/ventas_limpias.csv.

ETAPA 3 — Validación
Revisa el archivo limpio contra el original.
Criterio: las filas de salida deben ser menos o iguales que las de entrada,
y toda diferencia debe estar justificada por la etapa 2. Si algo no cuadra,
PÁRATE y dímelo en vez de continuar.

ETAPA 4 — Reporte
Genera output/reporte_ventas_febrero.md con: resumen ejecutivo de 3 líneas,
tabla de GMV por categoría y por región, y una sección final con las
decisiones de limpieza que tomaste.

Cuando termines, dame una tabla con las cuatro etapas y sus conteos.
```

**Verificación mientras corre:** mira el panel de tareas. Vas a ver el trabajo partiéndose en piezas. Eso es la coordinación de subagentes — lo mismo que el track técnico monta a mano en su Tema 8.

---

## Paso 4: Verificar por Conteos

No leas el reporte todavía. Primero comprueba los números:

| Etapa | Esperado | Obtenido |
|---|---|---|
| Extracción | 17 filas | |
| Limpieza | 14 filas (2 duplicados + 1 sin cantidad) | |
| Validación | Sin incoherencias | |
| Carga | 14 filas en el reporte | |

**La regla:** `extraídas ≥ limpias == reportadas`. Si los conteos no cuadran, el reporte no vale por bien redactado que esté.

**Otros resultados que también son correctos**, y por qué:

- **15 filas:** conservó la fila sin `cantidad` en vez de descartarla.
- **13 filas:** descartó *las dos* filas incompletas (la que no tiene `cantidad` y la que no tiene `precio_unitario`).

Ninguno de los tres es un error por sí mismo. Lo que decide si el trabajo está bien hecho es el punto siguiente.

---

## Paso 5: El Momento de la Decisión

Hay dos filas incompletas en el dataset y **no son el mismo problema**:

- Falta `cantidad` (fila del 2024-02-16). Sin cantidad no hay GMV para esa fila.
- Falta `precio_unitario` (fila del 2024-02-18). Igual.

La pregunta no tiene respuesta correcta única: ¿se descartan, o se conservan marcadas como incompletas?

- **Descartarlas** limpia el cálculo pero pierde información de una venta que sí ocurrió.
- **Conservarlas** mantiene el recuento de transacciones pero infravalora el GMV.

**Lo que sí es exigible:** que el reporte diga cuál de las dos hizo y por qué. Búscalo en la sección de decisiones de limpieza.

Si no lo dice, díselo:

```
No veo en el reporte qué hiciste con las dos filas incompletas.
Dime cuáles eran, qué decidiste y cómo afecta al GMV total.
```

Ese razonamiento *es* el entregable del ejercicio, más que el CSV.

---

## Paso 6: Comparar los Dos Encargos

Ahora sí, abre el resultado del Paso 2 al lado del de la Etapa 4.

Preguntas para el grupo:

1. ¿El encargo vago dijo cuántas filas eliminó?
2. ¿Podrías defender su cifra de GMV ante dirección?
3. Si el resultado estuviera mal, ¿en qué punto lo detectarías?

Casi siempre el encargo vago produce un reporte que **parece** igual de bueno. La diferencia no está en el texto: está en que uno se puede auditar y el otro no.

---

## Conexión con el Track Técnico

| Tú | Equipo técnico |
|---|---|
| Etapas dentro de un encargo | Un agent `.md` por etapa (extractor, transformer, loader) |
| Criterio de aceptación en prosa | Un agent `quality-checker` con umbrales numéricos |
| Claude coordina solo | Ellos son el coordinador: relevan el resultado de cada etapa |
| Ves el panel de tareas | Ven los `agentId` y pueden reanudar una etapa concreta |

Su versión puede **detener el pipeline** cuando una validación falla. La tuya avisa y sigue si tú no le has dicho que pare — por eso el encargo lleva escrito *"PÁRATE y dímelo"*. Es la misma distinción de FO-4: instrucción contra garantía.

## Checklist de Finalización

- [ ] Dataset sucio inspeccionado a ojo
- [ ] Encargo vago ejecutado y guardado para comparar
- [ ] Encargo por etapas con criterios de aceptación
- [ ] Conteos verificados: 17 → 14
- [ ] Decisión sobre las filas incompletas, explícita en el reporte
- [ ] Los dos resultados comparados

## Tip

La plantilla que acabas de usar sirve para cualquier encargo largo, no solo para datos:

```
ETAPA n — Nombre
Qué hacer.
Criterio: cómo sé que salió bien, en números.
Si no se cumple: párate y dime.
```

Cuando repitas este encargo por tercera vez, ya sabes qué toca: conviértelo en una Skill (FO-3). Ahí es donde se cierra el track — tu procedimiento de trabajo, guardado, invocable con `/`.
