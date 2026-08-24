# Índices Vectoriales y Optimización

**Ejercicio 12 - 20 minutos**

---

## Objetivo

Dominar los diferentes tipos de índices vectoriales, criterios de selección según caso de uso, y técnicas de optimización para balancear precisión, velocidad y costo.

## Contexto

El vector store del Tema 10 funciona para prototipos, pero no escala: compara la query contra **todos** los vectores, uno por uno. En producción necesitas índices especializados capaces de buscar entre millones de vectores en milisegundos. La elección del índice correcto puede significar la diferencia entre 10 ms y 10 segundos de latencia.

## Conceptos Clave

- **Dense Index:** Búsqueda basada en embeddings (vectores densos)
- **Sparse Index:** Búsqueda basada en keywords (vectores sparse, TF-IDF/BM25)
- **Hybrid Index:** Combina dense + sparse para mejor recall
- **ANN (Approximate Nearest Neighbors):** Algoritmos que sacrifican precisión por velocidad
- **Recall@k:** Qué fracción de los k vecinos verdaderos devuelve el índice aproximado

---

## Paso 0: Preparación

### 0a. Instalar FAISS

```bash
source .venv/bin/activate      # Windows: .venv\Scripts\Activate.ps1

pip install faiss-cpu
```

**Verificación:**
```bash
python -c "import faiss; print('FAISS', faiss.__version__)"
# Esperado: FAISS 1.x.x
```

> Si `faiss-cpu` falla en tu plataforma (Windows con Python muy nuevo), usa `pip install faiss-cpu --only-binary :all:` o ejecuta este tema dentro de WSL.

### 0b. Instalar psutil (para medir memoria en el benchmark)

```bash
pip install psutil
```

### 0c. Verificar que existe el módulo RAG del Tema 10

```bash
ls src/rag/
# Esperado: __init__.py chunking.py embeddings.py vector_store.py indexer.py ...
```

---

## Paso 1: Tipos de Índices Vectoriales

```
┌────────────────────────────────────────────────────────────────┐
│                    TIPOS DE ÍNDICES                            │
├────────────────┬───────────────┬───────────────┬──────────────┤
│ TIPO           │ VELOCIDAD     │ PRECISIÓN     │ MEMORIA      │
├────────────────┼───────────────┼───────────────┼──────────────┤
│ Flat (Brute)   │ Lento O(n)    │ 100%          │ Baja         │
│ IVF            │ Medio         │ 95-99%        │ Media        │
│ HNSW           │ Rápido        │ 98-99%        │ Alta         │
│ PQ (Product Q) │ Muy rápido    │ 90-95%        │ Muy baja     │
│ IVF-PQ         │ Rápido        │ 92-97%        │ Baja         │
│ ScaNN          │ Muy rápido    │ 95-98%        │ Media        │
└────────────────┴───────────────┴───────────────┴──────────────┘
```

**Cómo funciona cada uno, en una frase:**
- **Flat:** compara con todos. Exacto por definición.
- **IVF:** agrupa los vectores en `nlist` clusters; en la query solo mira los `nprobe` clusters más cercanos.
- **HNSW:** construye un grafo navegable multinivel; salta de vecino en vecino hacia el más parecido.
- **PQ:** comprime cada vector en un código corto; menos memoria, más error.
- **IVF-PQ:** clusters + compresión. El caballo de batalla para millones de vectores.

---

## Paso 2: Selector de Índice por Requisitos

### 2a. Crear el archivo

```bash
touch src/rag/index_selector.py
```

### 2b. Contenido completo de `src/rag/index_selector.py`

```python
# src/rag/index_selector.py

from enum import Enum
from dataclasses import dataclass


class IndexType(Enum):
    FLAT = "flat"           # Exacto, para < 10K vectores
    IVF = "ivf"             # Bueno para 10K-1M vectores
    HNSW = "hnsw"           # Mejor precisión, más memoria
    PQ = "pq"               # Mínima memoria, menor precisión
    IVF_PQ = "ivf_pq"       # Balance para millones de vectores
    SCANN = "scann"         # Optimizado para hardware específico


@dataclass
class IndexRecommendation:
    index_type: IndexType
    reason: str
    params: dict


def recommend_index(
    num_vectors: int,
    query_latency_ms: int,
    memory_budget_gb: float,
    precision_requirement: float = 0.95
) -> IndexRecommendation:
    """
    Recomienda índice basado en requisitos.

    Args:
        num_vectors: Número estimado de vectores
        query_latency_ms: Latencia máxima aceptable
        memory_budget_gb: Memoria disponible
        precision_requirement: Recall mínimo requerido (0-1)
    """
    # Estimación de memoria para embeddings de 384 dims en float32
    vector_size_mb = num_vectors * 384 * 4 / 1024 / 1024

    # Caso 1: Dataset pequeño
    if num_vectors < 10_000:
        return IndexRecommendation(
            index_type=IndexType.FLAT,
            reason="Dataset pequeño, búsqueda exacta es viable",
            params={}
        )

    # Caso 2: Latencia crítica
    if query_latency_ms < 10:
        if memory_budget_gb * 1024 >= vector_size_mb * 1.5:
            return IndexRecommendation(
                index_type=IndexType.HNSW,
                reason="Latencia crítica, suficiente memoria para HNSW",
                params={"m": 32, "ef_construction": 200}
            )
        return IndexRecommendation(
            index_type=IndexType.IVF_PQ,
            reason="Latencia crítica, memoria limitada",
            params={"nlist": int(num_vectors ** 0.5), "m": 8}
        )

    # Caso 3: Precisión crítica
    if precision_requirement > 0.98:
        return IndexRecommendation(
            index_type=IndexType.HNSW,
            reason="Alta precisión requerida",
            params={"m": 48, "ef_construction": 400, "ef_search": 200}
        )

    # Caso 4: Dataset grande, balance
    if num_vectors > 1_000_000:
        return IndexRecommendation(
            index_type=IndexType.IVF_PQ,
            reason="Dataset grande, balance memoria/velocidad",
            params={"nlist": int(num_vectors ** 0.5), "m": 16, "nbits": 8}
        )

    # Caso default
    return IndexRecommendation(
        index_type=IndexType.IVF,
        reason="Caso general, buen balance",
        params={"nlist": int(4 * (num_vectors ** 0.5))}
    )


if __name__ == "__main__":
    escenarios = [
        ("Documentación interna del equipo", 5_000, 100, 8.0, 0.95),
        ("Base de conocimiento corporativa", 250_000, 50, 4.0, 0.95),
        ("Búsqueda en tiempo real de producto", 800_000, 5, 32.0, 0.95),
        ("Corpus masivo, servidor pequeño", 5_000_000, 50, 2.0, 0.92),
    ]
    for nombre, n, lat, mem, prec in escenarios:
        rec = recommend_index(n, lat, mem, prec)
        print(f"{nombre}\n  → {rec.index_type.value.upper()}: {rec.reason}\n  params={rec.params}\n")
```

### 2c. Ejecutar el selector

```bash
python -m src.rag.index_selector
```

**Salida esperada:** cuatro recomendaciones distintas (FLAT, IVF, HNSW, IVF_PQ). Léelas: el objetivo de este paso es que la decisión salga de números, no de intuición.

---

## Paso 3: Implementación con FAISS

### 3a. Crear el archivo

```bash
touch src/rag/faiss_store.py
```

### 3b. Contenido completo de `src/rag/faiss_store.py`

```python
# src/rag/faiss_store.py

import numpy as np
from typing import List, Dict, Tuple, Optional
import faiss
import pickle
import os


class FAISSVectorStore:
    """
    Vector store optimizado usando FAISS.

    Sustituye a SimpleVectorStore (Tema 10) manteniendo la misma interfaz
    de búsqueda, para que el resto del pipeline RAG no cambie.
    """

    def __init__(
        self,
        dimension: int = 384,
        index_type: str = "ivf",
        store_path: str = ".claude/rag/faiss"
    ):
        self.dimension = dimension
        self.index_type = index_type.lower()
        self.store_path = store_path

        os.makedirs(store_path, exist_ok=True)

        self.index: Optional[faiss.Index] = None
        self.documents: List[Dict] = []
        self.is_trained = False

        self._load_or_create()

    def _create_index(self, num_vectors: int = 10000):
        """Crea índice según tipo especificado."""
        if self.index_type == "flat":
            self.index = faiss.IndexFlatIP(self.dimension)   # Inner Product
            self.is_trained = True

        elif self.index_type == "ivf":
            nlist = max(1, min(int(4 * (num_vectors ** 0.5)), num_vectors // 39 or 1))
            quantizer = faiss.IndexFlatIP(self.dimension)
            self.index = faiss.IndexIVFFlat(quantizer, self.dimension, nlist)

        elif self.index_type == "hnsw":
            self.index = faiss.IndexHNSWFlat(self.dimension, 32)
            self.index.hnsw.efSearch = 128
            self.is_trained = True

        elif self.index_type == "ivf_pq":
            nlist = max(1, int(num_vectors ** 0.5))
            m = 8                                            # Subvectores
            quantizer = faiss.IndexFlatIP(self.dimension)
            self.index = faiss.IndexIVFPQ(quantizer, self.dimension, nlist, m, 8)

        else:
            raise ValueError(f"index_type no soportado: {self.index_type}")

    def _load_or_create(self):
        """Carga índice existente o crea uno nuevo."""
        index_file = os.path.join(self.store_path, "index.faiss")
        docs_file = os.path.join(self.store_path, "documents.pkl")

        if os.path.exists(index_file) and os.path.exists(docs_file):
            self.index = faiss.read_index(index_file)
            with open(docs_file, 'rb') as f:
                self.documents = pickle.load(f)
            self.is_trained = True
        else:
            self._create_index()

    def _save(self):
        """Persiste índice y documentos."""
        faiss.write_index(self.index, os.path.join(self.store_path, "index.faiss"))
        with open(os.path.join(self.store_path, "documents.pkl"), 'wb') as f:
            pickle.dump(self.documents, f)

    def add_documents(self, chunks: List[Dict], embeddings: np.ndarray):
        """
        Añade documentos al índice.

        Args:
            chunks: Lista de documentos con metadata
            embeddings: Array numpy (n, dimension) en float32
        """
        embeddings = np.ascontiguousarray(embeddings, dtype='float32')

        # Normalizar para que el inner product equivalga a coseno
        faiss.normalize_L2(embeddings)

        # IVF y IVF-PQ requieren entrenamiento previo
        if not self.index.is_trained:
            print(f"Entrenando índice {self.index_type} con {len(embeddings)} vectores...")
            self.index.train(embeddings)
        self.is_trained = True

        self.index.add(embeddings)
        self.documents.extend(chunks)

        self._save()
        print(f"Añadidos {len(chunks)} documentos. Total en índice: {self.index.ntotal}")

    def search(
        self,
        query_embedding: np.ndarray,
        top_k: int = 5
    ) -> List[Tuple[Dict, float]]:
        """Busca documentos similares a un embedding de query."""
        query_embedding = np.ascontiguousarray(
            query_embedding.reshape(1, -1), dtype='float32'
        )
        faiss.normalize_L2(query_embedding)

        scores, indices = self.index.search(query_embedding, top_k)

        results = []
        for idx, score in zip(indices[0], scores[0]):
            if 0 <= idx < len(self.documents):
                results.append((self.documents[idx], float(score)))

        return results

    def optimize(self):
        """Ajusta parámetros de búsqueda para mejor recall."""
        if hasattr(self.index, 'nprobe'):
            self.index.nprobe = max(1, min(20, self.index.nlist // 4))
            print(f"nprobe ajustado a {self.index.nprobe}")

        if hasattr(self.index, 'hnsw'):
            self.index.hnsw.efSearch = 256
            print("efSearch ajustado a 256")
```

### 3c. Migrar el índice del Tema 10 a FAISS

```bash
touch src/rag/migrate_to_faiss.py
```

Contenido de `src/rag/migrate_to_faiss.py`:

```python
# src/rag/migrate_to_faiss.py
"""Migra el SimpleVectorStore (Tema 10) a un índice FAISS."""

import numpy as np
from .vector_store import SimpleVectorStore
from .faiss_store import FAISSVectorStore
from .embeddings import get_embedding


def main():
    simple = SimpleVectorStore()
    if not simple.documents:
        raise SystemExit("Índice vacío. Ejecuta primero: python -m src.rag.indexer")

    # Con pocos documentos, 'flat' es el índice correcto (ver Paso 2)
    faiss_store = FAISSVectorStore(dimension=simple.vectors.shape[1], index_type="flat")
    faiss_store.add_documents(simple.documents, np.array(simple.vectors))

    # Prueba de búsqueda
    q = get_embedding("valores nulos en cantidad")
    print("\nResultados FAISS:")
    for doc, score in faiss_store.search(np.array(q), top_k=3):
        print(f"  {score:.3f}  {doc['source']} §{doc.get('section','')}")


if __name__ == "__main__":
    main()
```

Ejecutar:

```bash
python -m src.rag.migrate_to_faiss
```

**Salida esperada:**
```
Añadidos N documentos. Total en índice: N

Resultados FAISS:
  0.6xx  docs/convenciones_datos.md §Convenciones de Datos del Equipo
  ...
```

**Verificación en disco:**
```bash
ls -la .claude/rag/faiss/
# Esperado: index.faiss y documents.pkl
```

---

## Paso 4: Benchmarking de Índices

Aquí es donde el tema cobra sentido: medir en vez de suponer.

### 4a. Crear el archivo

```bash
touch src/rag/benchmark.py
```

### 4b. Contenido completo de `src/rag/benchmark.py`

```python
# src/rag/benchmark.py
"""Benchmark comparativo de índices FAISS con vectores sintéticos."""

import time
from dataclasses import dataclass
from typing import List

import numpy as np
import faiss


@dataclass
class BenchmarkResult:
    index_type: str
    build_time_sec: float
    query_time_ms: float
    recall_at_10: float
    memory_mb: float


def _make_index(name: str, dimension: int, num_train: int):
    """Crea un índice FAISS por nombre."""
    if name == "Flat":
        return faiss.IndexFlatIP(dimension)

    if name == "IVF":
        nlist = max(1, min(int(4 * num_train ** 0.5), num_train // 39 or 1))
        return faiss.IndexIVFFlat(faiss.IndexFlatIP(dimension), dimension, nlist)

    if name == "HNSW":
        return faiss.IndexHNSWFlat(dimension, 32)

    if name == "IVF-PQ":
        nlist = max(1, min(int(num_train ** 0.5), num_train // 39 or 1))
        return faiss.IndexIVFPQ(faiss.IndexFlatIP(dimension), dimension, nlist, 8, 8)

    raise ValueError(name)


def benchmark_index(
    index,
    name: str,
    train_vectors: np.ndarray,
    test_vectors: np.ndarray,
    ground_truth: np.ndarray,
    num_queries: int = 100
) -> BenchmarkResult:
    """Evalúa build time, latencia y recall@10 de un índice."""
    import psutil

    start = time.time()
    if not index.is_trained:
        index.train(train_vectors)
    index.add(train_vectors)
    build_time = time.time() - start

    memory_mb = psutil.Process().memory_info().rss / 1024 / 1024

    query_times, recalls = [], []
    for i in range(min(num_queries, len(test_vectors))):
        query = test_vectors[i:i + 1]

        start = time.time()
        _, indices = index.search(query, 10)
        query_times.append((time.time() - start) * 1000)

        retrieved = set(indices[0].tolist())
        relevant = set(ground_truth[i][:10].tolist())
        recalls.append(len(retrieved & relevant) / len(relevant))

    return BenchmarkResult(
        index_type=name,
        build_time_sec=build_time,
        query_time_ms=float(np.mean(query_times)),
        recall_at_10=float(np.mean(recalls)),
        memory_mb=memory_mb
    )


def run_benchmark_suite(num_vectors: int = 20_000, dimension: int = 384) -> List[BenchmarkResult]:
    """Ejecuta el benchmark comparativo de todos los índices."""
    rng = np.random.default_rng(42)
    vectors = rng.random((num_vectors, dimension), dtype='float32')
    faiss.normalize_L2(vectors)

    split = int(len(vectors) * 0.99)
    train, test = vectors[:split].copy(), vectors[split:].copy()

    # Ground truth con búsqueda exacta
    flat = faiss.IndexFlatIP(dimension)
    flat.add(train)
    _, ground_truth = flat.search(test, 10)

    results = []
    for name in ["Flat", "IVF", "HNSW", "IVF-PQ"]:
        print(f"Benchmarking {name}...")
        index = _make_index(name, dimension, len(train))
        result = benchmark_index(index, name, train, test, ground_truth)
        results.append(result)
        print(f"  build={result.build_time_sec:.2f}s  "
              f"query={result.query_time_ms:.3f}ms  "
              f"recall@10={result.recall_at_10:.1%}")

    return results


if __name__ == "__main__":
    print(f"{'ÍNDICE':<10}{'BUILD(s)':>10}{'QUERY(ms)':>12}{'RECALL@10':>12}")
    print("-" * 44)
    for r in run_benchmark_suite():
        print(f"{r.index_type:<10}{r.build_time_sec:>10.2f}{r.query_time_ms:>12.3f}{r.recall_at_10:>11.1%}")
```

### 4c. Ejecutar el benchmark

```bash
python -m src.rag.benchmark
```

**Salida esperada** (los números varían por máquina, el patrón no):

```
ÍNDICE      BUILD(s)   QUERY(ms)   RECALL@10
--------------------------------------------
Flat            0.01       0.450      100.0%
IVF             0.35       0.090       6x.x%
HNSW            2.10       0.060       9x.x%
IVF-PQ          0.60       0.055       3x.x%
```

**Cómo leer esto:**
- **Flat** es el único con 100% de recall — es la referencia, no un competidor.
- **IVF** con `nprobe=1` (default) tiene recall bajo. Súbelo y el recall sube con él.
- **HNSW** da la mejor relación recall/latencia, a costa de build time y memoria.
- **IVF-PQ** es el más rápido y ligero, y el que más precisión pierde.

> Ojo: con vectores aleatorios uniformes (como aquí) el recall de los índices aproximados se ve peor que con embeddings reales, porque no hay estructura de clusters que explotar. El objetivo del ejercicio es ver el **trade-off**, no el número absoluto.

### 4d. Demostrar el efecto de nprobe

```bash
python -c "
import numpy as np, faiss, time
rng = np.random.default_rng(0)
v = rng.random((20000, 384), dtype='float32'); faiss.normalize_L2(v)
train, test = v[:19800].copy(), v[19800:].copy()
flat = faiss.IndexFlatIP(384); flat.add(train)
_, gt = flat.search(test, 10)

idx = faiss.IndexIVFFlat(faiss.IndexFlatIP(384), 384, 200)
idx.train(train); idx.add(train)
for nprobe in [1, 5, 20, 50, 200]:
    idx.nprobe = nprobe
    t0 = time.time(); _, r = idx.search(test, 10); ms = (time.time()-t0)/len(test)*1000
    rec = np.mean([len(set(r[i]) & set(gt[i]))/10 for i in range(len(test))])
    print(f'nprobe={nprobe:>3}  recall={rec:.1%}  latencia={ms:.3f}ms')
"
```

**Qué observar:** `nprobe` es la perilla del trade-off. `nprobe = nlist` equivale a búsqueda exacta (recall 100%) pero pierde toda la ventaja de velocidad.

---

## Paso 5: Optimización Automática de Parámetros (Opcional)

### 5a. Instalar Optuna

```bash
pip install optuna
```

### 5b. Crear el archivo

```bash
touch src/rag/index_tuning.py
```

### 5c. Contenido completo de `src/rag/index_tuning.py`

```python
# src/rag/index_tuning.py
"""Búsqueda automática de hiperparámetros de índices con Optuna."""

import time
import numpy as np
import faiss
import optuna

optuna.logging.set_verbosity(optuna.logging.WARNING)


def compute_recall(indices: np.ndarray, ground_truth: np.ndarray, k: int = 10) -> float:
    """Recall@k promedio entre resultados aproximados y exactos."""
    return float(np.mean([
        len(set(indices[i][:k].tolist()) & set(ground_truth[i][:k].tolist())) / k
        for i in range(len(indices))
    ]))


def tune_hnsw(
    vectors: np.ndarray,
    test_queries: np.ndarray,
    ground_truth: np.ndarray,
    latency_target_ms: float = 5.0,
    n_trials: int = 20
) -> dict:
    """Optimiza parámetros de HNSW penalizando si excede la latencia objetivo."""

    def objective(trial):
        m = trial.suggest_int('m', 8, 64, step=8)
        ef_construction = trial.suggest_int('ef_construction', 100, 500, step=50)
        ef_search = trial.suggest_int('ef_search', 50, 300, step=25)

        index = faiss.IndexHNSWFlat(vectors.shape[1], m)
        index.hnsw.efConstruction = ef_construction
        index.add(vectors)
        index.hnsw.efSearch = ef_search

        start = time.time()
        _, indices = index.search(test_queries, 10)
        latency = (time.time() - start) / len(test_queries) * 1000

        recall = compute_recall(indices, ground_truth)

        if latency > latency_target_ms:
            return recall * (latency_target_ms / latency)
        return recall

    study = optuna.create_study(direction='maximize')
    study.optimize(objective, n_trials=n_trials)
    return study.best_params


def tune_ivf(
    vectors: np.ndarray,
    test_queries: np.ndarray,
    ground_truth: np.ndarray,
    n_trials: int = 20
) -> dict:
    """Optimiza nlist y nprobe de IVF."""

    def objective(trial):
        max_nlist = max(100, min(int(len(vectors) ** 0.5), len(vectors) // 39))
        nlist = trial.suggest_int('nlist', 100, max_nlist, step=50)
        nprobe = trial.suggest_int('nprobe', 1, min(50, nlist), step=5)

        index = faiss.IndexIVFFlat(faiss.IndexFlatIP(vectors.shape[1]), vectors.shape[1], nlist)
        index.train(vectors)
        index.add(vectors)
        index.nprobe = nprobe

        _, indices = index.search(test_queries, 10)
        return compute_recall(indices, ground_truth)

    study = optuna.create_study(direction='maximize')
    study.optimize(objective, n_trials=n_trials)
    return study.best_params


if __name__ == "__main__":
    rng = np.random.default_rng(7)
    v = rng.random((20_000, 384), dtype='float32')
    faiss.normalize_L2(v)
    train, test = v[:19_900].copy(), v[19_900:].copy()

    flat = faiss.IndexFlatIP(384)
    flat.add(train)
    _, gt = flat.search(test, 10)

    print("Mejores parámetros IVF:", tune_ivf(train, test, gt, n_trials=10))
    print("Mejores parámetros HNSW:", tune_hnsw(train, test, gt, n_trials=10))
```

### 5d. Ejecutar

```bash
python -m src.rag.index_tuning
```

Tarda 1-3 minutos. **Salida esperada:** dos diccionarios de parámetros, por ejemplo `{'nlist': 400, 'nprobe': 46}`.

---

## Paso 6: Trade-offs y Decisiones

```
┌────────────────────────────────────────────────────────────────┐
│            MATRIZ DE DECISIÓN DE ÍNDICES                       │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  Vectores < 10K        → FLAT (exacto, simple)                │
│  Vectores 10K-100K     → HNSW (mejor recall)                  │
│                          IVF (menos memoria)                  │
│  Vectores 100K-1M      → HNSW (si hay RAM)                    │
│                          IVF-PQ (si RAM limitada)             │
│  Vectores > 1M         → IVF-PQ o ScaNN                       │
│                                                                │
│  Latencia < 1ms        → HNSW con ef_search bajo             │
│                          Requiere mucha RAM                   │
│  Latencia < 10ms       → IVF con nprobe optimizado           │
│  Latencia < 100ms      → Cualquier índice funciona           │
│                                                                │
│  Precisión > 99%       → FLAT (único exacto)                  │
│  Precisión > 95%       → HNSW o IVF bien tuneado             │
│  Precisión > 90%       → IVF-PQ aceptable                     │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

**Aplícala a tu caso real ahora:**

```bash
python -c "
from src.rag.index_selector import recommend_index
# Cambia estos números por los de TU proyecto
rec = recommend_index(num_vectors=50_000, query_latency_ms=50, memory_budget_gb=4, precision_requirement=0.95)
print(rec.index_type.value, '->', rec.reason, rec.params)
"
```

---

## Verificación Final del Ejercicio

```bash
python -c "import faiss, psutil; print('1. OK dependencias')"
python -m src.rag.index_selector > /dev/null && echo "2. OK selector"
python -c "
from src.rag.faiss_store import FAISSVectorStore
s = FAISSVectorStore(index_type='flat')
print(f'3. OK FAISS store con {s.index.ntotal} vectores')
"
python -m src.rag.benchmark && echo "4. OK benchmark"
```

---

## Conexión con Ejercicios Anteriores

- **Tema 10-11 (RAG):** el índice es el backend de almacenamiento; `AdvancedRAGPipeline` funciona igual con FAISS
- **Tema 6 (Optimización):** mismo tipo de trade-off costo/calidad que elegir Haiku vs Opus
- **Tema 9 (MCP):** podrías exponer la búsqueda vectorial como MCP server para que otros equipos la consuman
- **Tema 14 (Evaluación):** recall@10 es exactamente el tipo de métrica que va al golden dataset

## Checklist de Finalización

- [ ] `faiss-cpu` y `psutil` instalados y verificados
- [ ] `src/rag/index_selector.py` creado y ejecutado con los 4 escenarios
- [ ] `src/rag/faiss_store.py` creado
- [ ] Índice del Tema 10 migrado a FAISS (`python -m src.rag.migrate_to_faiss`)
- [ ] `.claude/rag/faiss/index.faiss` y `documents.pkl` existen
- [ ] `src/rag/benchmark.py` creado y ejecutado; tabla comparativa obtenida
- [ ] Demostrado el efecto de `nprobe` sobre recall y latencia
- [ ] (Opcional) `src/rag/index_tuning.py` ejecutado con Optuna
- [ ] Matriz de decisión aplicada a tu caso de uso real

## Recursos Adicionales

- [FAISS Documentation](https://github.com/facebookresearch/faiss/wiki)
- [Guidelines to choose an index (FAISS)](https://github.com/facebookresearch/faiss/wiki/Guidelines-to-choose-an-index)
- [ANN Benchmarks](http://ann-benchmarks.com/)

## Tip Avanzado

Implementa **índices sharded** para escalar horizontalmente cuando un solo proceso ya no aguanta el corpus:

```python
class ShardedVectorStore:
    """Distribuye vectores en múltiples shards para escalar."""

    def __init__(self, num_shards: int = 4):
        self.shards = [
            FAISSVectorStore(store_path=f".claude/rag/shard_{i}")
            for i in range(num_shards)
        ]

    def add(self, vectors: np.ndarray, docs: List[Dict]):
        # Sharding por hash del id: determinístico y balanceado
        for vec, doc in zip(vectors, docs):
            shard_id = hash(doc['id']) % len(self.shards)
            self.shards[shard_id].add_documents([doc], vec.reshape(1, -1))

    def search(self, query: np.ndarray, top_k: int) -> List[Tuple]:
        # Buscar en todos los shards y hacer merge global
        all_results = []
        for shard in self.shards:
            all_results.extend(shard.search(query, top_k))

        all_results.sort(key=lambda x: x[1], reverse=True)
        return all_results[:top_k]
```

Cada shard puede vivir en un proceso o máquina distinta; el merge es la única parte que debe ser central.
