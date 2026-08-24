#!/usr/bin/env bash
#
# generar-datos-muestra.sh — Genera los datos de muestra de los ejercicios del curso.
#
# Uso:
#   ./generar-datos-muestra.sh [DESTINO]
#
#   DESTINO  Directorio raiz del proyecto de practica (default: directorio actual).
#            Se crean DESTINO/data/ y DESTINO/output/.
#
# Ejemplos:
#   ./generar-datos-muestra.sh                    # genera en ./data y ./output
#   ./generar-datos-muestra.sh ../t1              # genera en ../t1/data y ../t1/output
#   FORCE=1 ./generar-datos-muestra.sh ../t1      # sobreescribe archivos existentes
#
# Los datos son DETERMINISTAS (no aleatorios): todos los participantes obtienen
# exactamente el mismo dataset, asi que los conteos de los ejercicios coinciden.

set -euo pipefail

DEST="${1:-.}"
DATA_DIR="$DEST/data"
OUTPUT_DIR="$DEST/output"

mkdir -p "$DATA_DIR" "$OUTPUT_DIR"

# Escribe $2 en el archivo $1, respetando archivos existentes salvo FORCE=1.
escribir() {
  local ruta="$1" contenido="$2"
  if [[ -e "$ruta" && "${FORCE:-0}" != "1" ]]; then
    echo "  = $ruta (ya existe, se conserva — usa FORCE=1 para sobreescribir)"
    return
  fi
  printf '%s' "$contenido" > "$ruta"
  echo "  + $ruta ($(grep -c . "$ruta") lineas no vacias)"
}

echo "Generando datos de muestra en: $DEST"

# ---------------------------------------------------------------------------
# data/ventas_2024.csv — dataset principal (Temas 01-08)
#
# Defectos INTENCIONALES, no descuidos. Cada uno existe para que un ejercicio
# tenga algo real que detectar:
#
#   1. Linea vacia antes del header  -> trampa de parseo; hay que saltarla
#   2. `cantidad` vacia (2024-01-15) -> el quality-checker (Tema 08) la detecta
#                                       y el transformer decide descartar o imputar
#
# NO cambies los conteos sin revisar los 11 lugares del curso que citan este
# archivo: 12 filas de datos, 6 columnas, 1 valor faltante.
# ---------------------------------------------------------------------------
escribir "$DATA_DIR/ventas_2024.csv" '
fecha,producto,categoria,region,cantidad,precio_unitario
2024-01-05,Laptop Pro 14,Electronica,Norte,3,1299.00
2024-01-06,Mouse Inalambrico,Accesorios,Norte,15,24.99
2024-01-08,Laptop Pro 14,Electronica,Sur,1,1299.00
2024-01-10,Teclado Mecanico,Accesorios,Centro,8,79.50
2024-01-12,Monitor 27in,Electronica,Norte,4,329.00
2024-01-15,Mouse Inalambrico,Accesorios,Sur,,24.99
2024-01-18,Silla Ergonomica,Mobiliario,Centro,2,215.00
2024-01-20,Laptop Pro 14,Electronica,Norte,3,1299.00
2024-01-22,Monitor 27in,Electronica,Centro,6,329.00
2024-01-25,Teclado Mecanico,Accesorios,Norte,10,79.50
2024-01-28,Escritorio Ajustable,Mobiliario,Sur,1,540.00
2024-01-30,Mouse Inalambrico,Accesorios,Centro,20,24.99
'

# ---------------------------------------------------------------------------
# data/ventas_2024_dirty.csv — variante SUCIA (Tema 08, opcional)
#
# El dataset principal ya viene con fechas en ISO y sin duplicados exactos, asi
# que dos de las tres transformaciones del Tema 08 (`removed_duplicates`,
# `normalized_dates`) no tienen efecto observable y el ejercicio queda hueco.
#
# Esta variante SI las ejercita:
#   - 3 formatos de fecha mezclados (ISO, DD/MM/YYYY, "15-Feb-2024")
#   - 2 duplicados exactos
#   - 1 `cantidad` vacia y 1 `precio_unitario` vacio
#   - espacios sobrantes alrededor de valores
#
# 17 filas de datos -> 14 tras limpiar (2 duplicados + 1 fila sin cantidad).
# Usala cuando quieras que el pipeline del Tema 08 reporte trabajo real.
# ---------------------------------------------------------------------------
escribir "$DATA_DIR/ventas_2024_dirty.csv" '
fecha,producto,categoria,region,cantidad,precio_unitario
2024-02-01,Laptop Pro 14,Electronica,Norte,2,1299.00
03/02/2024,Mouse Inalambrico,Accesorios,Sur,12,24.99
2024-02-05,Monitor 27in,Electronica,Centro,5,329.00
2024-02-05,Monitor 27in,Electronica,Centro,5,329.00
08/02/2024, Teclado Mecanico ,Accesorios,Norte,7,79.50
15-Feb-2024,Silla Ergonomica,Mobiliario,Sur,3,215.00
2024-02-16,Escritorio Ajustable,Mobiliario,Centro,,540.00
2024-02-18,Laptop Pro 14,Electronica,Sur,1,
20/02/2024,Mouse Inalambrico,Accesorios,Norte,18,24.99
2024-02-22,Monitor 27in,Electronica,Norte,4,329.00
2024-02-22,Monitor 27in,Electronica,Norte,4,329.00
25-Feb-2024,Teclado Mecanico,Accesorios,Centro,9,79.50
2024-02-26,Silla Ergonomica,Mobiliario,Norte,2,215.00
28/02/2024,Escritorio Ajustable,Mobiliario,Sur,1,540.00
2024-02-29,Laptop Pro 14,Electronica,Centro,2,1299.00
2024-03-01,Mouse Inalambrico,Accesorios,Sur,25,24.99
2024-03-02,Monitor 27in,Electronica,Centro,3,329.00
'

# ---------------------------------------------------------------------------
# data/ventas_demo.csv — dataset minimo (Tema 06: conteo de tokens)
#
# Deliberadamente pequeno: sirve para comparar consumo de tokens entre modelos
# sin gastar contexto.
# ---------------------------------------------------------------------------
escribir "$DATA_DIR/ventas_demo.csv" 'fecha,producto,region,cantidad,precio_unitario
2024-01-05,Laptop Pro 14,Norte,3,1299.00
2024-01-06,Mouse Inalambrico,Norte,15,24.99
2024-01-08,Monitor 27in,Sur,4,329.00
'

echo
echo "Resumen:"
printf '  %-42s %s\n' "ARCHIVO" "FILAS DE DATOS"
for f in "$DATA_DIR/ventas_2024.csv" "$DATA_DIR/ventas_2024_dirty.csv" "$DATA_DIR/ventas_demo.csv"; do
  [[ -e "$f" ]] || continue
  # grep -c . = lineas no vacias; -1 por el header
  printf '  %-42s %s\n' "${f#"$DEST"/}" "$(( $(grep -c . "$f") - 1 ))"
done
echo
echo "Listo. output/ creado y vacio, listo para los ejercicios."
