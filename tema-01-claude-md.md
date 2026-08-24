# CLAUDE.md - Memoria del Proyecto

**Ejercicio 1 - 10 minutos**

---

## Objetivo

Configurar CLAUDE.md como la memoria persistente de tu proyecto, estableciendo el contexto que Claude Code usará en cada sesión.

## Contexto

CLAUDE.md es el archivo más importante de tu proyecto para Claude Code. Es lo primero que Claude lee al iniciar una sesión, conteniendo reglas, convenciones y contexto crítico. Sin él, Claude empieza cada conversación desde cero. Con él, Claude entiende tu stack, tus preferencias y las restricciones del proyecto.

## Conceptos Clave

- **CLAUDE.md:** Archivo de configuración en la raíz del proyecto que Claude lee automáticamente
- **Contexto Persistente:** Información que persiste entre sesiones sin necesidad de repetirla
- **Instrucciones de Proyecto:** Reglas específicas que Claude debe seguir siempre

---

## Paso 1: Crear la Estructura Base

Creamos el archivo CLAUDE.md en la raíz del proyecto con secciones organizadas.

```bash
cd ~/tu-proyecto
touch CLAUDE.md
```

Contenido inicial:

```markdown
# Proyecto: Sistema de Análisis de Datos

## Stack Tecnológico
- Python 3.11+
- pandas, numpy, scikit-learn
- PostgreSQL para datos transaccionales
- DuckDB para análisis OLAP
- pytest para testing

## Convenciones de Código
- Usar type hints en todas las funciones
- Docstrings en formato Google
- Variables en snake_case
- Clases en PascalCase

## Estructura del Proyecto
```
src/
  analyzers/    # Módulos de análisis
  connectors/   # Conexiones a bases de datos
  utils/        # Utilidades compartidas
tests/          # Tests unitarios y de integración
data/           # Datos de ejemplo (NO commitear datos reales)
```

## Reglas Críticas
- NUNCA hardcodear credenciales
- Siempre validar inputs antes de procesarlos
- Logs en formato estructurado (JSON)
- Todo análisis debe ser reproducible
```

**Verificación:** 
```bash
cat CLAUDE.md | head -20
```

---

## Paso 2: Agregar Contexto de Negocio

Claude trabaja mejor cuando entiende el "por qué" del proyecto.

```markdown
## Contexto de Negocio

Este sistema automatiza el análisis de datos de ventas para el equipo de 
Business Intelligence. Los usuarios principales son:
- Data Analysts: Generan reportes semanales
- Data Scientists: Construyen modelos predictivos
- Product Managers: Consultan métricas de producto

### Métricas Clave
- GMV (Gross Merchandise Value)
- Conversion Rate
- Customer Lifetime Value (CLV)
- Churn Rate

### Fuentes de Datos
- `sales_db`: Base transaccional principal
- `analytics_dw`: Data Warehouse para reportes
- `events_lake`: Event streaming (Kafka → S3)
```

**Verificación:** Abre una nueva sesión de Claude Code y pregunta "¿Cuáles son las métricas clave del proyecto?" - debería responder sin que le expliques nada.

---

## Paso 3: Definir Preferencias de Claude

Indica cómo quieres que Claude se comporte en este proyecto.

```markdown
## Preferencias para Claude

### Al escribir código
- Preferir funciones puras sobre efectos secundarios
- Usar dataclasses o Pydantic para modelos de datos
- Dividir funciones largas en funciones más pequeñas
- Incluir ejemplos en docstrings

### Al explicar
- Ser conciso, evitar explicaciones obvias
- Usar ejemplos concretos con datos del proyecto
- Si hay trade-offs, presentar pros/cons

### Al debuggear
- Primero reproducir el error
- Verificar inputs antes de asumir bugs en lógica
- Sugerir tests que prevengan regresiones
```

**Verificación:** Pide a Claude que escriba una función de ejemplo y verifica que siga las preferencias.

---

## Paso 4: Documentar Patrones del Proyecto

Incluye patrones específicos que Claude debe replicar.

```markdown
## Patrones del Proyecto

### Patrón: Analyzer
Todos los módulos de análisis heredan de `BaseAnalyzer`:

\`\`\`python
from src.analyzers.base import BaseAnalyzer

class SalesAnalyzer(BaseAnalyzer):
    def __init__(self, config: AnalyzerConfig):
        super().__init__(config)
    
    def analyze(self, data: pd.DataFrame) -> AnalysisResult:
        # Implementación específica
        pass
\`\`\`

### Patrón: Connector
Conexiones a datos usan el patrón Factory:

\`\`\`python
from src.connectors import ConnectorFactory

connector = ConnectorFactory.create("postgresql", config)
with connector.connect() as conn:
    df = conn.query("SELECT * FROM sales")
\`\`\`
```

---

## Conexión con Ejercicios Anteriores

Este es el primer ejercicio. CLAUDE.md será la base para todo lo que construyamos después:
- Los Skills (Tema 3) leerán contexto de aquí
- Los Hooks (Tema 4-5) validarán contra estas reglas
- Los Subagents (Tema 7) heredarán este contexto

## Checklist de Finalización

- [ ] Archivo CLAUDE.md creado en la raíz
- [ ] Stack tecnológico documentado
- [ ] Contexto de negocio incluido
- [ ] Preferencias de Claude definidas
- [ ] Patrones del proyecto con ejemplos de código

## Recursos Adicionales

- [Documentación oficial de CLAUDE.md](https://docs.anthropic.com/claude-code/claude-md)
- Archivo de ejemplo en `/examples/CLAUDE.md.example`

## Tip Avanzado

Puedes tener múltiples archivos CLAUDE.md en subdirectorios. Claude los lee jerárquicamente: primero el de la raíz, luego el del directorio actual. Útil para monorepos donde cada módulo tiene reglas específicas.

```
proyecto/
├── CLAUDE.md              # Reglas globales
├── backend/
│   └── CLAUDE.md          # Reglas específicas de backend
└── frontend/
    └── CLAUDE.md          # Reglas específicas de frontend
```
