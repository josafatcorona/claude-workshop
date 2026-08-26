# Alcance, Permisos y Elección de Modelo

**Ejercicio FO-2 - 15 minutos**

*Espeja los Temas 2 y 6 del track técnico (settings.json / Modelos y tokens)*

---

## Objetivo

Controlar tres cosas que determinan si Claude te ayuda o te estorba: **qué puede ver**, **qué puede hacer sin preguntarte** y **con qué modelo trabaja**.

## Contexto

En el track técnico esto es un archivo de configuración con listas de permisos. Aquí son tres controles de la interfaz, y conviene entenderlos porque son **lo único de este track que es una garantía y no una sugerencia** (volveremos a esa distinción en FO-4).

La regla de fondo es la misma en las dos superficies: dale a Claude el acceso mínimo que necesita para el trabajo que le encargas. No por desconfianza — por higiene. Un agente que ve 40.000 archivos trabaja peor que uno que ve 12.

## Conceptos Clave

- **Alcance:** la carpeta del proyecto. Es el borde de lo que Claude puede leer y escribir
- **Modo de permiso:** cuánta autonomía tiene antes de preguntarte
- **Modelo:** qué versión de Claude atiende la tarea
- **Higiene de contexto:** cuándo seguir en la misma tarea y cuándo abrir una nueva

---

## Paso 1: Revisar el Alcance

Vuelve a la configuración del proyecto de FO-1 y mira qué carpeta le diste.

**Regla práctica:** una carpeta dedicada al trabajo, nunca tu carpeta de usuario, nunca el escritorio entero.

Motivos concretos, en orden de importancia:

1. **Calidad.** Claude explora lo que ve. Con la carpeta correcta encuentra `ventas_2024.csv` en un paso; con tu disco entero se pasea por tus fotos.
2. **Coste.** Cada exploración innecesaria consume contexto de la tarea.
3. **Riesgo.** Lo que no está en el alcance no se puede leer ni pisar por accidente.

**Verificación — comprueba el borde:** en una tarea, pídele algo de fuera:

```
Lee el primer archivo de mi carpeta de Descargas y dime qué es
```

Debe negarse o pedirte acceso explícito. Si te lo lee sin más, el alcance del proyecto es más ancho de lo que crees: corrígelo antes de seguir.

---

## Paso 2: Elegir el Modo de Permiso

El selector de modo está junto al botón de enviar. Lo que hay que saber para este taller:

| Modo | Cuándo usarlo en tu día a día |
|---|---|
| **Manual** | Primera semana, o cuando toques datos que no puedes rehacer. Apruebas cada cambio |
| **Aceptar ediciones** | El punto dulce para trabajo de análisis: crea y edita archivos solo, te pregunta antes de correr comandos |
| **Auto** | Tareas largas de FO-5, cuando ya confías en el encargo. Ejecuta con verificaciones de seguridad en segundo plano |

Empieza en **Manual** hoy. Sube a **Aceptar ediciones** en cuanto te canses de aprobar la creación de archivos en `output/` — que será pronto, y esa impaciencia es la señal correcta.

**Verificación:** en Manual, pídele que cree `output/prueba.md` con una línea. Debe aparecerte la aprobación antes de escribir nada.

> **Ojo:** cambiar de modo no cambia el alcance. Un modo permisivo sobre una carpeta pequeña es seguro; un modo restrictivo sobre todo tu disco solo te hace aprobar cosas todo el día. **El alcance manda.**

---

## Paso 3: Elegir el Modelo

El desplegable de modelo está junto al de permisos, y se puede cambiar a mitad de tarea.

Traducción de la matriz del track técnico a tu trabajo:

| Lo que estás haciendo | Modelo |
|---|---|
| Interpretar resultados, decidir qué contar a dirección, redactar conclusiones | El más capaz disponible |
| Análisis del día a día, generar el reporte, limpiar datos | El intermedio — cubre el 80% |
| Reformatear, renombrar, extraer una cifra concreta, traducir | El más rápido |

**Regla práctica:** empieza por el intermedio. Sube cuando la respuesta te parezca superficial o el problema tenga juicio de por medio. Baja cuando la tarea sea mecánica y repetitiva.

**Verificación:** pide el mismo resumen de `ventas_2024.csv` con dos modelos distintos y compara. En una tarea así de pequeña la diferencia será menor — ese es justo el aprendizaje: **no pagues capacidad que la tarea no necesita.**

---

## Paso 4: Higiene de Contexto

Nadie te enseña esto y es lo que más rendimiento te va a dar.

Una tarea acumula todo lo hablado. Eso es bueno mientras el tema sea el mismo, y malo en cuanto cambias de asunto: Claude sigue arrastrando lo anterior, se vuelve más lento y a veces mezcla.

**Sigue en la misma tarea cuando:** iteras sobre el mismo análisis, corriges algo que acaba de hacer, o profundizas en un resultado que ya está en pantalla.

**Abre una tarea nueva cuando:** cambias de dataset, cambias de pregunta de negocio, o notas que las respuestas empiezan a ir a peor.

**Verificación:** al terminar el análisis de hoy, abre una tarea nueva para la siguiente pregunta en vez de encadenarla. Nota la diferencia en la primera respuesta.

---

## Regla de Oro — Versión Front Office

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

Esta tabla te va a acompañar el resto del track. La última fila es la que más se malinterpreta y tiene su propio ejercicio (FO-4).

## Conexión con el Track Técnico

| Tú | Equipo técnico |
|---|---|
| Carpeta del proyecto | Directorio de trabajo + reglas `Read`/`Write` en `settings.json` |
| Selector de modo | `permissions.defaultMode` y listas `allow`/`deny` |
| Desplegable de modelo | Clave `model` y `model:` en cada agent/skill |
| Abrir tarea nueva | `/clear`, compactación de contexto |

Ellos pueden expresar cosas que tú no: *"puede leer todo el repo pero solo escribir en `src/`"*, o *"jamás ejecutar `rm -rf`"*. Si necesitas un límite tan fino, es una petición para ellos — apúntala, la usarás en FO-7.

## Checklist de Finalización

- [ ] Alcance revisado: carpeta dedicada, no el disco entero
- [ ] Borde comprobado: pidió acceso para algo de fuera
- [ ] Modo de permiso elegido conscientemente
- [ ] Probado el mismo análisis con dos modelos
- [ ] Entendido cuándo abrir tarea nueva

## Tip

Si te pasas el día aprobando la misma acción inocua, no estás siendo prudente: estás entrenándote para aprobar sin leer. Sube el modo de permiso y baja el alcance. Es más seguro tener autonomía amplia sobre una carpeta pequeña que autonomía estrecha sobre todo.
