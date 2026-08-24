# Tu Primer Skill (Básico)

**Ejercicio 3 - 15 minutos**

---

## Objetivo

Crear tu primer Skill de Claude Code: un comando reutilizable que automatiza tareas específicas de tu proyecto.

## Contexto

Los Skills son como funciones guardadas que Claude puede ejecutar. A diferencia de pedirle algo cada vez, un Skill encapsula instrucciones complejas en un comando simple (`/mi-skill`). Piensa en ellos como scripts inteligentes: entienden contexto, toman decisiones y ejecutan múltiples pasos.

## Conceptos Clave

- **Skill:** Instrucciones empaquetadas que Claude ejecuta con `/nombre-skill`
- **Frontmatter:** Metadatos YAML al inicio del archivo que definen nombre, descripción y triggers
- **Prompt del Skill:** Las instrucciones que Claude sigue cuando el skill se invoca

---

## Paso 1: Crear el Directorio de Skills

Asegura que la estructura existe.

```bash
mkdir -p .claude/skills
```

---

## Paso 2: Crear un Skill de Análisis de Datos

Crearemos un skill que analiza un archivo CSV y genera un reporte. Un Skill es un **directorio** dentro de `.claude/skills/` que contiene un archivo `SKILL.md` (el nombre de archivo es fijo, no cambia por skill):

```bash
mkdir -p .claude/skills/analyze-csv
touch .claude/skills/analyze-csv/SKILL.md
```

Contenido del skill:

```markdown
---
name: analyze-csv
description: Analiza un archivo CSV y genera un reporte estadístico completo
arguments:
  - name: file
    description: Ruta al archivo CSV a analizar
    required: true
---

# Skill: Análisis de CSV

Cuando el usuario invoque este skill con un archivo CSV, sigue estos pasos:

## 1. Validación Inicial
- Verifica que el archivo existe
- Confirma que es un CSV válido
- Reporta el tamaño y número de filas

## 2. Análisis Exploratorio
Ejecuta el siguiente código Python:

\`\`\`python
import pandas as pd
import numpy as np

# Cargar datos
df = pd.read_csv("{{file}}")

# Información básica
print(f"Dimensiones: {df.shape[0]} filas x {df.shape[1]} columnas")
print(f"\nColumnas: {list(df.columns)}")
print(f"\nTipos de datos:\n{df.dtypes}")

# Estadísticas descriptivas
print(f"\nEstadísticas numéricas:\n{df.describe()}")

# Valores nulos
nulls = df.isnull().sum()
if nulls.any():
    print(f"\nValores nulos:\n{nulls[nulls > 0]}")

# Muestra de datos
print(f"\nPrimeras 5 filas:\n{df.head()}")
\`\`\`

## 3. Detección de Problemas
Busca y reporta:
- Columnas con más de 50% de valores nulos
- Posibles duplicados
- Columnas con un solo valor único (sin varianza)
- Tipos de datos inconsistentes

## 4. Recomendaciones
Basándote en el análisis, sugiere:
- Columnas a eliminar (si aplica)
- Transformaciones recomendadas
- Posibles análisis adicionales

## Output
Genera un resumen estructurado con:
- Métricas clave del dataset
- Problemas encontrados
- Recomendaciones priorizadas
```

**Verificación:**
```bash
cat .claude/skills/analyze-csv/SKILL.md
```

---

## Paso 3: Crear Datos de Muestra

El skill necesita un CSV real para analizar. Creamos uno pequeño que usaremos también en el Tema 7 (subagents):

```bash
mkdir -p data
touch data/ventas_2024.csv
```

Contenido de `data/ventas_2024.csv`:

```csv
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
```

**Verificación:**
```bash
python -c "import pandas as pd; print(pd.read_csv('data/ventas_2024.csv').shape)"
```

Nota que la fila de `2024-01-15` tiene `cantidad` vacía a propósito, para que el skill tenga un valor nulo real que detectar en el paso de "Detección de Problemas".

---

## Paso 4: Usar el Skill

Invoca el skill desde Claude Code:

```bash
# En la terminal de Claude Code
/analyze-csv file=data/ventas_2024.csv
```

O simplemente:
```
/analyze-csv data/ventas_2024.csv
```

Claude ejecutará automáticamente todos los pasos definidos.

---

## Paso 5: Crear un Skill de Generación de Tests

Skill más avanzado que genera tests para una función.

```bash
mkdir -p .claude/skills/gen-tests
touch .claude/skills/gen-tests/SKILL.md
```

Contenido de `.claude/skills/gen-tests/SKILL.md`:

```markdown
---
name: gen-tests
description: Genera tests unitarios para una función Python
arguments:
  - name: function
    description: Nombre de la función o ruta archivo:función
    required: true
---

# Skill: Generador de Tests

## Proceso

1. **Localizar la función**
   - Si es `archivo.py:funcion`, lee ese archivo
   - Si es solo `funcion`, búscala en src/

2. **Analizar la función**
   - Extrae signature y type hints
   - Identifica edge cases posibles
   - Revisa el docstring para ejemplos

3. **Generar tests**
   Crea tests siguiendo el patrón del proyecto:

   \`\`\`python
   import pytest
   from {{module}} import {{function}}

   class Test{{FunctionPascalCase}}:
       """Tests para {{function}}"""
       
       def test_caso_base(self):
           """Test del caso de uso principal"""
           # Arrange
           input_data = ...
           expected = ...
           
           # Act
           result = {{function}}(input_data)
           
           # Assert
           assert result == expected
       
       def test_edge_case_empty(self):
           """Test con input vacío"""
           ...
       
       def test_edge_case_invalid(self):
           """Test con input inválido"""
           with pytest.raises(ValueError):
               {{function}}(invalid_input)
   \`\`\`

4. **Ejecutar tests**
   ```bash
   pytest tests/test_{{module}}.py -v
   ```

5. **Reportar resultados**
   - Tests generados
   - Coverage logrado
   - Sugerencias de tests adicionales
```

---

## Paso 6: Skill con Múltiples Argumentos

Skill más completo para análisis comparativo.

```bash
mkdir -p .claude/skills/compare-datasets
touch .claude/skills/compare-datasets/SKILL.md
```

Contenido de `.claude/skills/compare-datasets/SKILL.md`:

```markdown
---
name: compare-datasets
description: Compara dos datasets y reporta diferencias
arguments:
  - name: baseline
    description: Archivo CSV de referencia
    required: true
  - name: current
    description: Archivo CSV actual a comparar
    required: true
  - name: key
    description: Columna clave para el join
    required: false
    default: id
---

# Skill: Comparación de Datasets

## Pasos

1. Cargar ambos archivos
2. Validar que tienen estructura compatible
3. Comparar:
   - Filas nuevas en current
   - Filas eliminadas vs baseline  
   - Filas modificadas (mismo key, valores diferentes)
4. Generar reporte de diferencias
5. Exportar diff a `output/diff_{{timestamp}}.csv`
```

---

## Conexión con Ejercicios Anteriores

- **Tema 1 (CLAUDE.md):** El skill lee el contexto de CLAUDE.md para seguir convenciones
- **Tema 2 (settings.json):** Los permisos definidos determinan qué puede hacer el skill

```
┌─────────────────────────────────────────────────────────┐
│              REGLA DE ORO: ¿QUÉ USAR?                 │
├─────────────────────┬──────────────────────────────────┤
│ SKILL               │ Cosas que el agente DEBE SABER   │
│ HOOK                │ Cosas que SIEMPRE SUCEDEN        │
│ SUBAGENT            │ Cosas que SE DELEGAN            │
│ MCP                 │ INTEGRACIÓN con servicios ext.  │
│ CLAUDE.md           │ Memoria + contexto del proyecto │
└─────────────────────┴──────────────────────────────────┘
```

**Skills = Comandos reutilizables que encapsulan tareas complejas**

## Checklist de Finalización

- [ ] Directorio .claude/skills/ creado
- [ ] data/ventas_2024.csv creado
- [ ] Skill analyze-csv/SKILL.md funcional
- [ ] Skill gen-tests/SKILL.md creado
- [ ] Probado invocar skills con /nombre
- [ ] Argumentos funcionan correctamente

## Recursos Adicionales

- [Guía de Skills](https://code.claude.com/docs/en/skills.md)

## Tip Avanzado

Los skills pueden llamar a otros skills internamente:

```markdown
## Paso Final
Después del análisis, ejecuta:
- /gen-tests para las funciones que procesen estos datos
- /lint para verificar el código generado
```

También pueden tener **triggers automáticos** que los invocan sin necesidad de `/comando`:

```yaml
---
name: auto-lint
triggers:
  - filePattern: "src/**/*.py"
    event: "afterWrite"
---
```

---

## Bonus: `skill-creator` — un skill para crear skills

Hasta aquí escribiste los SKILL.md a mano, que es exactamente lo que hay que hacer la primera
vez: se aprende la anatomía del archivo. A partir de la tercera o cuarta skill, conviene
delegar el andamiaje.

### Qué es

`skill-creator` es un **plugin oficial de Anthropic** que aporta una skill del mismo nombre.
No genera un SKILL.md y se va: te lleva por el ciclo completo de construcción.

| Fase | Qué hace |
|---|---|
| **Entrevista** | Te pregunta qué debe hacer la skill, con qué frases debe dispararse y qué output esperas |
| **Borrador** | Escribe el SKILL.md con la estructura correcta (frontmatter, pasos, output) |
| **Test prompts** | Propone casos de prueba y los corre contra la skill |
| **Evaluación** | Trae scripts propios para medir resultados y comparar iteraciones |
| **Afinado de `description`** | Optimiza la línea que decide **cuándo se dispara** la skill — el punto que más falla en la práctica |

Ese último punto es el que justifica la herramienta. Una `description` mal escrita produce una
skill que existe pero nunca se invoca, o que se invoca cuando no toca.

### Cómo se instala

El marketplace oficial ya viene registrado en Claude Code, así que es un comando:

```
/plugin install skill-creator@claude-plugins-official
```

Alternativa interactiva: `/plugin` → *Browse marketplaces* → `claude-plugins-official` →
`skill-creator`.

Para comprobar que quedó activo:

```
/plugin          # aparece en la lista de instalados
```

### Cómo se usa

No trae slash commands propios. Se activa **por descripción de intención**:

```
Crea una skill que valide los CSV de data/ antes de procesarlos
Mejora la description de mi skill analyze-csv, casi nunca se dispara
Corre evals sobre gen-tests y dime dónde falla
```

O invocándola de forma explícita:

```
/skill-creator:skill-creator
```

> **Convención de nombres:** las skills que vienen de un plugin se invocan como
> `plugin:skill`. Por eso el doble nombre — el plugin se llama `skill-creator` y la skill
> dentro de él también.

### Plugin hermano: `plugin-dev`

Si además de skills quieres empaquetar hooks, agents, comandos o servers MCP —es decir, todo
lo que verás de los Temas 4 al 9— el paquete es:

```
/plugin install plugin-dev@claude-plugins-official
```

Aporta 8 skills (`skill-development`, `hook-development`, `command-development`,
`agent-development`, `mcp-integration`, `plugin-structure`, `plugin-settings`,
`create-plugin`) y tres agents, entre ellos `skill-reviewer`, que revisa una skill ya escrita
y sugiere mejoras.

**Regla práctica para elegir:** `skill-creator` para *construir y medir* una skill;
`plugin-dev` para *empaquetar y distribuir* un conjunto de piezas.

### Cuándo NO usarlo

- **Tu primera skill.** Escríbela a mano. Si delegas el andamiaje antes de entender el
  frontmatter, luego no sabes depurar por qué no se dispara.
- **Skills de 10 líneas.** El ciclo de evals cuesta más que la skill.
- Su valor aparece con skills que otros van a usar, o cuando el disparo automático importa.
