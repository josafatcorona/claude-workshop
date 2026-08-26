---
name: analizar-ventas
description: Analiza un archivo CSV de ventas y produce un resumen ejecutivo con métricas de negocio, calidad de datos y recomendaciones. Úsala cuando pidan analizar, revisar, resumir o sacar métricas de un archivo de ventas, un CSV de transacciones o un export de pedidos.
---

# Análisis de un archivo de ventas

## Qué necesitas del usuario

La ruta del archivo a analizar. Si no la dice y hay un solo CSV de ventas en la
carpeta del proyecto, usa ese y avisa de cuál elegiste. Si hay varios, lista los
candidatos y pregunta.

## 1. Reconocimiento

Abre el archivo y reporta, en una sola línea: número de filas de datos, número de
columnas y el rango de fechas que cubre.

Ojo con dos defectos frecuentes en estos exports: puede haber una línea en blanco
antes del encabezado, y puede haber espacios sobrantes alrededor de los valores.
Trátalos antes de contar.

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
Nunca imputes un valor faltante sin decirlo. Si un dato no se puede recuperar, la
respuesta correcta es decir que falta, no inventar un promedio.

## 5. Salida

Termina con:

- Tres líneas de resumen ejecutivo, sin jerga
- La tabla de métricas
- La lista de problemas encontrados, si los hay
- Máximo tres recomendaciones, ordenadas por impacto
