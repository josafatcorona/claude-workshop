# RAG Básico - Chunking y Embeddings

**Ejercicio 10 - 20 minutos**

---

## Objetivo

Implementar un sistema RAG (Retrieval-Augmented Generation) básico que permite a Claude acceder a documentación histórica y conocimiento del proyecto mediante búsqueda semántica.

## Contexto

RAG resuelve el problema de que Claude no puede "recordar" todo tu proyecto. En lugar de meter todo en el prompt (costoso e imposible para proyectos grandes), indexamos documentos y recuperamos solo los fragmentos relevantes para cada pregunta. Es como darle a Claude acceso a una biblioteca con un bibliotecario inteligente.

## Conceptos Clave

- **RAG:** Retrieval-Augmented Generation - combinar búsqueda con generación
- **Chunking:** Dividir documentos en fragmentos manejables
- **Embeddings:** Vectores numéricos que representan el significado semántico
- **Vector Store:** Base de datos optimizada para búsqueda por similitud

---

## Paso 0: Preparación del Entorno

### 0a. Verificar Python

```bash
python --version   # o python3 --version
# Esperado: Python 3.10 o superior
```

### 0b. Crear entorno virtual (recomendado)

```bash
python -m venv .venv

# Activar - Linux/macOS:
source .venv/bin/activate
# Activar - Windows (PowerShell):
# .venv\Scripts\Activate.ps1

# Verificar que está activo:
which python    # Debe apuntar a .venv/bin/python
```

### 0c. Instalar dependencias

```bash
pip install sentence-transformers numpy
```

> La primera ejecución descargará el modelo `all-MiniLM-L6-v2` (~90 MB). **Hazlo antes del taller** si tu conexión es lenta:
> ```bash
> python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('all-MiniLM-L6-v2')"
> ```

### 0d. Crear la estructura de carpetas del módulo RAG

```bash
mkdir -p src/rag
mkdir -p docs reports
mkdir -p .claude/rag/store .claude/rag/cache

# Hacer de src/ y src/rag/ paquetes Python importables
touch src/__init__.py
touch src/rag/__init__.py
```

**Verificación:**
```bash
find src -type f
# Esperado:
# src/__init__.py
# src/rag/__init__.py
```

---

## Paso 1: Estructura del Sistema RAG

Este es el flujo que vas a construir en los pasos 2 a 6:

```
┌─────────────────────────────────────────────────────────┐
│                    SISTEMA RAG                          │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   INDEXACIÓN (offline)                                  │
│   ┌──────────┐    ┌──────────┐    ┌──────────────┐     │
│   │Documentos│ →  │ Chunking │ →  │  Embeddings  │     │
│   └──────────┘    └──────────┘    └──────┬───────┘     │
│                     Paso 2          Paso 3              │
│                                          ▼              │
│                                   ┌──────────────┐     │
│                                   │ Vector Store │     │
│                                   │   Paso 4     │     │
│                                   └──────────────┘     │
│                                          ▲              │
│   CONSULTA (online)                      │              │
│   ┌──────────┐    ┌──────────┐    ┌──────┴───────┐     │
│   │  Query   │ →  │ Embedding│ →  │   Búsqueda   │     │
│   └──────────┘    └──────────┘    └──────┬───────┘     │
│                                          │              │
│                                          ▼              │
│   ┌──────────┐    ┌──────────┐    ┌──────────────┐     │
│   │ Respuesta│ ← │  Claude   │ ← │   Contexto   │     │
│   └──────────┘    └──────────┘    └──────────────┘     │
│                                       Paso 6            │
└─────────────────────────────────────────────────────────┘
```

---

## Paso 2: Implementar Chunking

### 2a. Crear el archivo

```bash
touch src/rag/chunking.py
```

### 2b. Contenido completo de `src/rag/chunking.py`

```python
# src/rag/chunking.py

from typing import List, Dict
import re


def chunk_text(
    text: str,
    chunk_size: int = 500,
    chunk_overlap: int = 50
) -> List[Dict]:
    """
    Divide texto en chunks con overlap para mantener contexto.

    Args:
        text: Texto completo a dividir
        chunk_size: Número aproximado de caracteres por chunk
        chunk_overlap: Caracteres de overlap entre chunks consecutivos

    Returns:
        Lista de diccionarios con texto y metadata del chunk
    """
    # Limpiar texto
    text = re.sub(r'\n{3,}', '\n\n', text)
    text = text.strip()

    chunks = []
    start = 0
    chunk_id = 0

    while start < len(text):
        # Encontrar el final del chunk
        end = start + chunk_size

        # Ajustar al final de una oración o párrafo
        if end < len(text):
            last_break = max(
                text.rfind('.', start, end),
                text.rfind('\n', start, end),
                text.rfind('!', start, end),
                text.rfind('?', start, end)
            )
            if last_break > start + chunk_size // 2:
                end = last_break + 1

        chunk_body = text[start:end].strip()

        if chunk_body:
            chunks.append({
                "id": f"chunk_{chunk_id}",
                "text": chunk_body,
                "start_char": start,
                "end_char": end,
                "char_count": len(chunk_body)
            })
            chunk_id += 1

        # Mover al siguiente chunk con overlap
        start = end - chunk_overlap

    return chunks


def chunk_markdown(content: str, source_file: str) -> List[Dict]:
    """
    Chunking especializado para Markdown, respetando secciones.
    """
    chunks = []
    current_section = ""
    current_text = ""
    chunk_id = 0

    for line in content.split('\n'):
        # Detectar headers
        if line.startswith('#'):
            if current_text.strip():
                chunks.append({
                    "id": f"{source_file}:chunk_{chunk_id}",
                    "text": current_text.strip(),
                    "section": current_section,
                    "source": source_file,
                    "type": "markdown"
                })
                chunk_id += 1

            current_section = line.lstrip('#').strip()
            current_text = line + '\n'
        else:
            current_text += line + '\n'

            # Si el chunk es muy grande, dividir
            if len(current_text) > 1000:
                chunks.append({
                    "id": f"{source_file}:chunk_{chunk_id}",
                    "text": current_text.strip(),
                    "section": current_section,
                    "source": source_file,
                    "type": "markdown"
                })
                chunk_id += 1
                current_text = ""

    # Último chunk
    if current_text.strip():
        chunks.append({
            "id": f"{source_file}:chunk_{chunk_id}",
            "text": current_text.strip(),
            "section": current_section,
            "source": source_file,
            "type": "markdown"
        })

    return chunks
```

### 2c. Probar el chunking aisladamente

```bash
python -c "
from src.rag.chunking import chunk_text
texto = 'Frase uno. ' * 200
chunks = chunk_text(texto, chunk_size=300, chunk_overlap=30)
print(f'Chunks generados: {len(chunks)}')
print(f'Primer chunk ({chunks[0][\"char_count\"]} chars): {chunks[0][\"text\"][:60]}...')
"
```

**Salida esperada:** un número de chunks > 1 y el texto del primero. Si falla con `ModuleNotFoundError: No module named 'src'`, confirma que estás en la raíz del proyecto y que existen los `__init__.py` del Paso 0d.

---

## Paso 3: Generar Embeddings

### 3a. Crear el archivo

```bash
touch src/rag/embeddings.py
```

### 3b. Contenido completo de `src/rag/embeddings.py`

```python
# src/rag/embeddings.py

import numpy as np
from typing import List, Optional
import hashlib
import json
import os

# Para producción, usar la API de Anthropic/Voyage/OpenAI.
# Aquí usamos una implementación local con sentence-transformers.

try:
    from sentence_transformers import SentenceTransformer
    EMBEDDINGS_MODEL = SentenceTransformer('all-MiniLM-L6-v2')
except ImportError:
    EMBEDDINGS_MODEL = None


def get_embedding(text: str) -> List[float]:
    """Genera embedding para un texto."""
    if EMBEDDINGS_MODEL is None:
        raise ImportError("Instala sentence-transformers: pip install sentence-transformers")

    embedding = EMBEDDINGS_MODEL.encode(text, convert_to_numpy=True)
    return embedding.tolist()


def get_embeddings_batch(texts: List[str], batch_size: int = 32) -> List[List[float]]:
    """Genera embeddings en batch para eficiencia."""
    if EMBEDDINGS_MODEL is None:
        raise ImportError("Instala sentence-transformers")

    embeddings = EMBEDDINGS_MODEL.encode(
        texts,
        batch_size=batch_size,
        show_progress_bar=True,
        convert_to_numpy=True
    )
    return embeddings.tolist()


def cosine_similarity(vec1: List[float], vec2: List[float]) -> float:
    """Calcula similitud coseno entre dos vectores."""
    a = np.array(vec1)
    b = np.array(vec2)
    return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b)))


class EmbeddingsCache:
    """Cache de embeddings para evitar recálculos."""

    def __init__(self, cache_dir: str = ".claude/rag/cache"):
        self.cache_dir = cache_dir
        os.makedirs(cache_dir, exist_ok=True)

    def _hash_text(self, text: str) -> str:
        return hashlib.md5(text.encode()).hexdigest()

    def get(self, text: str) -> Optional[List[float]]:
        hash_key = self._hash_text(text)
        cache_file = os.path.join(self.cache_dir, f"{hash_key}.json")

        if os.path.exists(cache_file):
            with open(cache_file, 'r') as f:
                return json.load(f)
        return None

    def set(self, text: str, embedding: List[float]):
        hash_key = self._hash_text(text)
        cache_file = os.path.join(self.cache_dir, f"{hash_key}.json")

        with open(cache_file, 'w') as f:
            json.dump(embedding, f)

    def get_or_compute(self, text: str) -> List[float]:
        cached = self.get(text)
        if cached:
            return cached

        embedding = get_embedding(text)
        self.set(text, embedding)
        return embedding
```

### 3c. Probar los embeddings

```bash
python -c "
from src.rag.embeddings import get_embedding, cosine_similarity
a = get_embedding('las ventas de laptops crecieron en el norte')
b = get_embedding('el volumen de portátiles subió en la región norte')
c = get_embedding('receta de pastel de chocolate')
print(f'Dimensión del vector: {len(a)}')
print(f'Similitud a-b (deben parecerse): {cosine_similarity(a,b):.3f}')
print(f'Similitud a-c (no deben):        {cosine_similarity(a,c):.3f}')
"
```

**Salida esperada:** dimensión 384, similitud a-b alta (>0.6) y a-c baja (<0.3). Esta es la demostración de que el embedding captura significado, no palabras.

---

## Paso 4: Vector Store

### 4a. Crear el archivo

```bash
touch src/rag/vector_store.py
```

### 4b. Contenido completo de `src/rag/vector_store.py`

```python
# src/rag/vector_store.py

import json
import os
from typing import List, Dict, Tuple, Optional
import numpy as np
from .embeddings import get_embedding, get_embeddings_batch


class SimpleVectorStore:
    """
    Vector store simple basado en archivos.
    Para producción, usar FAISS (Tema 12), ChromaDB, Pinecone, etc.
    """

    def __init__(self, store_path: str = ".claude/rag/store"):
        self.store_path = store_path
        self.index_file = os.path.join(store_path, "index.json")
        self.vectors_file = os.path.join(store_path, "vectors.npy")

        os.makedirs(store_path, exist_ok=True)

        self.documents: List[Dict] = []
        self.vectors: Optional[np.ndarray] = None

        self._load()

    def _load(self):
        """Carga índice existente."""
        if os.path.exists(self.index_file):
            with open(self.index_file, 'r') as f:
                self.documents = json.load(f)

        if os.path.exists(self.vectors_file):
            self.vectors = np.load(self.vectors_file)

    def _save(self):
        """Persiste el índice."""
        with open(self.index_file, 'w') as f:
            json.dump(self.documents, f, indent=2)

        if self.vectors is not None:
            np.save(self.vectors_file, self.vectors)

    def add_documents(self, chunks: List[Dict]):
        """Añade chunks al vector store."""
        texts = [chunk['text'] for chunk in chunks]
        embeddings = get_embeddings_batch(texts)

        self.documents.extend(chunks)

        new_vectors = np.array(embeddings)
        if self.vectors is None:
            self.vectors = new_vectors
        else:
            self.vectors = np.vstack([self.vectors, new_vectors])

        self._save()
        print(f"Añadidos {len(chunks)} documentos. Total: {len(self.documents)}")

    def search(
        self,
        query: str,
        top_k: int = 5,
        threshold: float = 0.2
    ) -> List[Tuple[Dict, float]]:
        """
        Busca documentos similares a la query.

        Returns:
            Lista de tuplas (documento, score) ordenadas por relevancia
        """
        if self.vectors is None or len(self.documents) == 0:
            return []

        query_embedding = np.array(get_embedding(query))

        similarities = np.dot(self.vectors, query_embedding) / (
            np.linalg.norm(self.vectors, axis=1) * np.linalg.norm(query_embedding)
        )

        top_indices = np.argsort(similarities)[::-1][:top_k]

        results = []
        for idx in top_indices:
            score = similarities[idx]
            if score >= threshold:
                results.append((self.documents[idx], float(score)))

        return results

    def clear(self):
        """Limpia el store completo."""
        self.documents = []
        self.vectors = None
        if os.path.exists(self.index_file):
            os.remove(self.index_file)
        if os.path.exists(self.vectors_file):
            os.remove(self.vectors_file)
```

> **Nota sobre `threshold`:** con `all-MiniLM-L6-v2` los scores de coseno rara vez pasan de 0.7. Un umbral de 0.5 descarta resultados válidos; por eso usamos 0.2 en el curso. Ajústalo midiendo, no adivinando.

---

## Paso 5: Crear los Documentos y el Pipeline de Indexación

### 5a. Crear documentos de muestra

Antes de indexar necesitas documentos reales. Crea dos que simulan el conocimiento histórico del equipo:

```bash
touch docs/convenciones_datos.md
touch reports/analisis_ventas_q1_2024.md
```

Contenido de `docs/convenciones_datos.md`:

```markdown
# Convenciones de Datos del Equipo

- Las fechas siempre se registran en formato ISO (YYYY-MM-DD).
- La columna `region` usa solo: Norte, Sur, Centro.
- Valores nulos en `cantidad` indican una venta registrada sin conteo físico
  (pendiente de auditoría), no una venta de cero unidades.
- El GMV se calcula como cantidad * precio_unitario, excluyendo devoluciones.
```

Contenido de `reports/analisis_ventas_q1_2024.md`:

```markdown
# Análisis de Ventas Q1 2024

## Resumen

Las ventas del Q1 2024 mostraron una concentración fuerte en la categoría
Electrónica, liderada por Laptop Pro 14. La región Norte representó el mayor
volumen de unidades vendidas.

## Hallazgos

- Laptop Pro 14 tuvo el precio unitario más alto y bajo volumen por transacción.
- Los Accesorios (Mouse Inalámbrico, Teclado Mecánico) mostraron alta rotación
  pero bajo ticket promedio.
- Se detectó una fila con `cantidad` nula en la región Sur, marcada para
  auditoría según la convención del equipo.

## Recomendaciones

- Dar seguimiento a la fila con dato faltante antes del cierre del reporte.
- Evaluar bundle de Accesorios + Electrónica para subir el ticket promedio.
```

**Verificación:**
```bash
wc -l docs/*.md reports/*.md
# Ambos archivos deben tener contenido (no 0 líneas)
```

### 5b. Crear el indexador

```bash
touch src/rag/indexer.py
```

Contenido completo de `src/rag/indexer.py`:

```python
# src/rag/indexer.py

import os
import glob
from typing import List
from .chunking import chunk_markdown, chunk_text
from .vector_store import SimpleVectorStore


def index_directory(
    directory: str,
    store: SimpleVectorStore,
    patterns: List[str] = None
):
    """Indexa todos los documentos de un directorio."""
    if patterns is None:
        patterns = ["**/*.md", "**/*.txt"]

    all_chunks = []

    for pattern in patterns:
        files = glob.glob(os.path.join(directory, pattern), recursive=True)

        for file_path in files:
            print(f"Indexando: {file_path}")

            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()

            # Elegir chunker según tipo de archivo
            if file_path.endswith('.md'):
                chunks = chunk_markdown(content, file_path)
            else:
                base_chunks = chunk_text(content)
                chunks = [
                    {**chunk, "source": file_path, "type": "text"}
                    for chunk in base_chunks
                ]

            all_chunks.extend(chunks)

    print(f"\nTotal chunks generados: {len(all_chunks)}")
    if all_chunks:
        store.add_documents(all_chunks)


if __name__ == "__main__":
    store = SimpleVectorStore()
    store.clear()   # Reindexado limpio en cada corrida del ejercicio

    index_directory("docs/", store)
    index_directory("reports/", store, patterns=["**/*.md"])

    print(f"\nÍndice listo con {len(store.documents)} chunks.")
```

### 5c. Ejecutar la indexación

```bash
python -m src.rag.indexer
```

**Salida esperada:**
```
Indexando: docs/convenciones_datos.md
Indexando: reports/analisis_ventas_q1_2024.md

Total chunks generados: 5
Batches: 100%|██████████| 1/1
Añadidos 5 documentos. Total: 5

Índice listo con 5 chunks.
```

**Verificación en disco:**
```bash
ls -la .claude/rag/store/
# Esperado: index.json y vectors.npy

python -c "
import numpy as np, json
print('Chunks:', len(json.load(open('.claude/rag/store/index.json'))))
print('Shape vectores:', np.load('.claude/rag/store/vectors.npy').shape)
"
# Esperado: Chunks: 5   Shape vectores: (5, 384)
```

### 5d. Probar la búsqueda semántica

```bash
python -c "
from src.rag.vector_store import SimpleVectorStore
store = SimpleVectorStore()
for doc, score in store.search('¿qué significa una cantidad vacía?', top_k=3):
    print(f'{score:.3f}  {doc[\"source\"]}  §{doc.get(\"section\",\"\")}')
    print(f'        {doc[\"text\"][:90]}...')
"
```

**Salida esperada:** el chunk de `docs/convenciones_datos.md` sobre valores nulos en primer lugar. Nota que la query **no contiene la palabra "nulo"** — eso es búsqueda semántica funcionando.

---

## Paso 6: Skill de RAG Search

### 6a. Crear la estructura

```bash
mkdir -p .claude/skills/rag-search
touch .claude/skills/rag-search/SKILL.md
```

### 6b. Contenido de `.claude/skills/rag-search/SKILL.md`

```markdown
---
name: rag-search
description: Busca en la documentación e histórico del proyecto usando RAG semántico
arguments:
  - name: query
    description: Pregunta o términos de búsqueda
    required: true
---

# RAG Search Skill

## Proceso

1. **Búsqueda semántica**

   Ejecuta este comando y usa su salida como contexto:

   \`\`\`bash
   python -c "
   from src.rag.vector_store import SimpleVectorStore
   store = SimpleVectorStore()
   for doc, score in store.search('{{query}}', top_k=5):
       print(f'--- [{doc[\"source\"]}] score={score:.3f}')
       print(doc['text'])
   "
   \`\`\`

2. **Construir contexto**

   Concatena los chunks recuperados. Si ningún chunk supera score 0.2,
   dilo explícitamente: "no hay contexto histórico relevante".

3. **Responder con contexto**

   Responde la pregunta original **solo** con lo que dicen los chunks.
   Cita la fuente entre corchetes al final de cada afirmación.
   Si el contexto no alcanza para responder, dilo — no inventes.
```

### 6c. Ejecutar y verificar

```
/rag-search query=¿cómo interpretamos las cantidades faltantes?
```

**Verificación:** Claude debe citar `docs/convenciones_datos.md` y explicar que un nulo significa "pendiente de auditoría", no cero.

### 6d. Añadir un hook de reindexado automático (opcional, conecta con Tema 5)

Para que el índice nunca quede obsoleto, reindexa cuando se escriba un `.md` en `docs/` o `reports/`:

```bash
touch .claude/hooks/reindex-rag.sh
chmod +x .claude/hooks/reindex-rag.sh
```

Contenido de `.claude/hooks/reindex-rag.sh`:

```bash
#!/bin/bash
# PostToolUse: reindexa el RAG si se escribió documentación
RAW=$(cat)
FILE=$(echo "$RAW" | jq -r '.tool_input.file_path // empty')

case "$FILE" in
  *docs/*.md|*reports/*.md)
    python -m src.rag.indexer > /dev/null 2>&1
    echo "RAG reindexado tras cambio en $FILE"
    ;;
esac
exit 0
```

Regístralo en `.claude/settings.json` dentro de `hooks.PostToolUse`:

```json
{
  "matcher": "Write",
  "hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/reindex-rag.sh"}]
}
```

---

## Verificación Final del Ejercicio

```bash
python -c "from src.rag.chunking import chunk_text; print('1. OK chunking')"
python -c "from src.rag.embeddings import get_embedding; print('2. OK embeddings')"
python -c "from src.rag.vector_store import SimpleVectorStore; s=SimpleVectorStore(); assert len(s.documents)>0; print(f'3. OK store con {len(s.documents)} chunks')"
python -c "
from src.rag.vector_store import SimpleVectorStore
r = SimpleVectorStore().search('ventas de electrónica', top_k=1)
assert r, 'sin resultados'
print(f'4. OK búsqueda -> {r[0][0][\"source\"]} ({r[0][1]:.3f})')
"
```

---

## Conexión con Ejercicios Anteriores

- **Tema 1 (CLAUDE.md):** RAG complementa CLAUDE.md para conocimiento que no cabe en el prompt
- **Tema 5 (Hooks):** el hook del Paso 6d mantiene el índice fresco automáticamente
- **Tema 9 (MCP):** podrías exponer `store.search()` como MCP server para otros agents
- **Tema 7-8 (Subagents):** un subagent especializado en retrieval evita contaminar el contexto principal

## Checklist de Finalización

- [ ] Entorno virtual creado y `sentence-transformers` instalado
- [ ] Estructura `src/rag/` con `__init__.py` en ambos niveles
- [ ] `src/rag/chunking.py` creado y probado (genera > 1 chunk)
- [ ] `src/rag/embeddings.py` creado y probado (dimensión 384, similitud coherente)
- [ ] `src/rag/vector_store.py` creado
- [ ] `docs/convenciones_datos.md` y `reports/analisis_ventas_q1_2024.md` con contenido
- [ ] `src/rag/indexer.py` creado y ejecutado con `python -m src.rag.indexer`
- [ ] `.claude/rag/store/index.json` y `vectors.npy` existen
- [ ] Búsqueda semántica devuelve el chunk correcto sin coincidencia literal de palabras
- [ ] Skill `rag-search` creado y probado
- [ ] (Opcional) Hook `reindex-rag.sh` registrado en settings.json

## Recursos Adicionales

- [Sentence Transformers](https://www.sbert.net/)
- [Contextual Retrieval (Anthropic)](https://www.anthropic.com/news/contextual-retrieval)

## Tip Avanzado

Implementa **chunking semántico** que respeta la estructura del documento en lugar de cortar por tamaño:

```python
def semantic_chunking(text: str) -> List[Dict]:
    """
    Divide por secciones lógicas, no solo por tamaño.
    - Funciones completas en código
    - Párrafos completos en prosa
    - Tablas íntegras
    """
    if is_code(text):
        return chunk_by_functions(text)
    elif has_tables(text):
        return chunk_preserving_tables(text)
    else:
        return chunk_by_paragraphs(text)
```

Un paso más allá: **contextual retrieval** — antes de generar el embedding, pide a Haiku que anteponga a cada chunk una frase que lo sitúe en el documento ("Este fragmento del reporte Q1 2024 habla de..."). Sube el recall de forma notable con un costo mínimo.
