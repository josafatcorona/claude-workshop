---
name: reporte-semanal
description: Genera el reporte semanal de métricas de ventas comparando la semana actual contra la anterior y lo deja listo para compartir. Úsala cuando pidan el reporte semanal, el weekly, el cierre de la semana, el resumen semanal de ventas o una comparativa semana contra semana.
---

# Reporte semanal de ventas

## Qué necesitas del usuario

La fuente de datos y la semana de referencia. Si no las dice, usa el CSV de ventas
más reciente de la carpeta del proyecto y la última semana completa, y di
explícitamente qué elegiste antes de seguir.

## 1. Métricas de la semana

Calcula sobre el rango de la semana de referencia:

- GMV total
- Número de transacciones
- Ticket medio
- GMV por categoría
- GMV por región

## 2. Comparativa con la semana anterior

Repite el cálculo para los siete días previos y obtén la variación porcentual de
cada métrica.

Si no hay datos suficientes para la semana anterior, dilo y marca las variaciones
como no disponibles. No compares contra un periodo incompleto sin advertirlo.

## 3. Redacción del reporte

Crea un archivo en la carpeta output/ con el nombre reporte_semanal_AAAA-MM-DD.md,
usando la fecha del último día del periodo. Estructura:

- **Resumen ejecutivo**: máximo tres líneas, sin jerga técnica. Empieza por lo que
  más se movió.
- **Tabla de métricas**: métrica, valor de esta semana, valor de la anterior,
  variación porcentual.
- **Qué explica los movimientos**: solo lo que puedas sostener con los datos. Si una
  variación no tiene explicación en el dataset, dilo en vez de especular.
- **Notas de calidad de datos**: filas descartadas, valores faltantes y cualquier
  decisión que hayas tomado sobre ellos.

## 4. Reglas que no se negocian

- Ninguna cifra inventada. Si falta un dato, se dice.
- Toda estimación va marcada como estimación.
- Si descartas filas, el reporte dice cuántas y por qué.

## 5. Distribución

Si el usuario pide publicarlo y hay un connector de mensajería disponible, publica
**solo el resumen ejecutivo** y la ruta del archivo completo. Enseña el texto exacto
antes de enviarlo.

Si no hay connector conectado, omite este paso y dilo al final.
