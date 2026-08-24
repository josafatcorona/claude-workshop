# RAG Avanzado - Hybrid Search y Reranking

**Ejercicio 11 - 20 minutos**

---

## Objetivo

Mejorar el sistema RAG básico con búsqueda híbrida (semántica + keyword), reranking para mejor precisión, y estrategias de contexto optimizadas.

## Contexto

El RAG básico funciona, pero tiene limitaciones: la búsqueda puramente semántica puede fallar con términos técnicos específicos, y el orden de resultados no siempre es óptimo. La búsqueda híbrida combina lo mejor de ambos mundos, y el reranking afina los resultados finales.

## Conceptos Clave

- **Hybrid Search:** Combina búsqueda semántica (embeddings) con keyword (BM25/TF-IDF)
- **Reranking:** Segundo pase para reordenar resultados por relevancia real
- **Query Expansion:** Enriquecer la query con términos relacionados
- **Contextual Compression:** Reducir chunks a solo lo relevante

---

## Paso 0: Preparación

Este ejercicio **construye sobre el Tema 10**. Verifica que el índice existe antes de empezar:

```bash
# 1. Entorno activo
source .venv/bin/activate     # Windows: .venv\Scripts\Activate.ps1

# 2. El índice del Tema 10 existe y tiene contenido
python -c "
from src.rag.vector_store import SimpleVectorStore
s = SimpleVectorStore()
print(f'Chunks indexados: {len(s.documents)}')
assert len(s.documents) > 0, 'Ejecuta primero: python -m src.rag.indexer'
"
```

Si el índice está vacío, vuelve al Tema 10 Paso 5c.

### 0a. Añadir documentación con términos técnicos

La búsqueda híbrida solo brilla cuando hay términos exactos que la semántica pierde. Crea un documento con jerga técnica:

```bash
touch docs/runbook_incidentes.md
```

Contenido de `docs/runbook_incidentes.md`:

```markdown
# Runbook de Incidentes

## PostgreSQL connection timeout

Si el pipeline falla con `PostgreSQL connection timeout`, revisa el pool de
conexiones en `src/db.py`. El valor por defecto de `statement_timeout` es 30s.

## ERR_GMV_MISMATCH

Este error aparece cuando el GMV calculado difiere del reportado por la API de
analytics en más del 0.5%. Casi siempre son devoluciones no excluidas.

## Reprocesar un día

Ejecuta `python -m src.pipeline --date YYYY-MM-DD --force`. Requiere aprobación
del data owner porque sobreescribe la partición.
```

Reindexa:

```bash
python -m src.rag.indexer
```

**Verificación:** el conteo de chunks debe haber aumentado respecto al Tema 10.

---

## Paso 1: Implementar BM25 para Keyword Search

### 1a. Crear el archivo

```bash
touch src/rag/keyword_search.py
```

### 1b. Contenido completo de `src/rag/keyword_search.py`

```python
# src/rag/keyword_search.py

import math
from collections import Counter
from typing import List, Dict, Tuple
import re


class BM25:
    """
    Implementación de BM25 para búsqueda por keywords.

    BM25 puntúa un documento por cuántas veces aparecen los términos de la
    query (TF), penalizando términos comunes (IDF) y documentos largos.
    """

    def __init__(self, k1: float = 1.5, b: float = 0.75):
        self.k1 = k1              # Saturación del term frequency
        self.b = b                # Peso de la normalización por longitud
        self.documents: List[List[str]] = []
        self.doc_lengths: List[int] = []
        self.avg_doc_length: float = 0
        self.doc_freqs: Dict[str, int] = {}
        self.idf: Dict[str, float] = {}
        self.doc_metadata: List[Dict] = []

    def _tokenize(self, text: str) -> List[str]:
        """Tokenización simple."""
        text = text.lower()
        return re.findall(r'\b\w+\b', text)

    def fit(self, documents: List[Dict]):
        """
        Indexa documentos para BM25.

        Args:
            documents: Lista de dicts con 'text' y metadata
        """
        if not documents:
            return

        self.doc_metadata = documents

        for doc in documents:
            tokens = self._tokenize(doc['text'])
            self.documents.append(tokens)
            self.doc_lengths.append(len(tokens))

            for token in set(tokens):
                self.doc_freqs[token] = self.doc_freqs.get(token, 0) + 1

        self.avg_doc_length = sum(self.doc_lengths) / len(self.doc_lengths)

        N = len(self.documents)
        for token, df in self.doc_freqs.items():
            self.idf[token] = math.log((N - df + 0.5) / (df + 0.5) + 1)

    def _score_document(self, query_tokens: List[str], doc_idx: int) -> float:
        """Calcula BM25 score para un documento."""
        doc = self.documents[doc_idx]
        doc_len = self.doc_lengths[doc_idx]
        term_freqs = Counter(doc)

        score = 0.0
        for token in query_tokens:
            if token not in self.idf:
                continue

            tf = term_freqs.get(token, 0)
            idf = self.idf[token]

            numerator = tf * (self.k1 + 1)
            denominator = tf + self.k1 * (1 - self.b + self.b * doc_len / self.avg_doc_length)
            score += idf * numerator / denominator

        return score

    def search(self, query: str, top_k: int = 10) -> List[Tuple[Dict, float]]:
        """
        Busca documentos por keywords.

        Returns:
            Lista de (documento, score) ordenada por relevancia
        """
        query_tokens = self._tokenize(query)

        scores = []
        for idx in range(len(self.documents)):
            score = self._score_document(query_tokens, idx)
            if score > 0:
                scores.append((idx, score))

        scores.sort(key=lambda x: x[1], reverse=True)

        return [(self.doc_metadata[idx], score) for idx, score in scores[:top_k]]
```

### 1c. Probar BM25 aisladamente

```bash
python -c "
from src.rag.vector_store import SimpleVectorStore
from src.rag.keyword_search import BM25

store = SimpleVectorStore()
bm25 = BM25()
bm25.fit(store.documents)

print('Query: ERR_GMV_MISMATCH')
for doc, score in bm25.search('ERR_GMV_MISMATCH', top_k=2):
    print(f'  {score:.3f}  {doc[\"source\"]}')
"
```

**Salida esperada:** `docs/runbook_incidentes.md` en primer lugar con score alto. Un código de error como `ERR_GMV_MISMATCH` es exactamente lo que la búsqueda semántica pierde y BM25 encuentra.

---

## Paso 2: Búsqueda Híbrida

### 2a. Crear el archivo

```bash
touch src/rag/hybrid_search.py
```

### 2b. Contenido completo de `src/rag/hybrid_search.py`

```python
# src/rag/hybrid_search.py

from typing import List, Dict, Tuple, Optional
from .vector_store import SimpleVectorStore
from .keyword_search import BM25


class HybridSearch:
    """
    Combina búsqueda semántica y por keywords.

    alpha = 1.0 → solo semántica
    alpha = 0.0 → solo keyword
    alpha = 0.5 → balance (default)
    """

    def __init__(
        self,
        vector_store: SimpleVectorStore,
        alpha: float = 0.5
    ):
        self.vector_store = vector_store
        self.alpha = alpha
        self.bm25 = BM25()

        # Indexar documentos en BM25
        if vector_store.documents:
            self.bm25.fit(vector_store.documents)

    def search(
        self,
        query: str,
        top_k: int = 5,
        semantic_weight: Optional[float] = None
    ) -> List[Tuple[Dict, float]]:
        """Búsqueda híbrida combinando semantic y keyword."""
        alpha = semantic_weight if semantic_weight is not None else self.alpha

        semantic_results = self.vector_store.search(query, top_k=top_k * 2)
        keyword_results = self.bm25.search(query, top_k=top_k * 2)

        semantic_scores = self._normalize_scores(semantic_results)
        keyword_scores = self._normalize_scores(keyword_results)

        combined = self._fuse_results(semantic_scores, keyword_scores, alpha)

        # combined es {doc_id: (doc, score)} -> ordenamos por score
        ranked = sorted(combined.values(), key=lambda x: x[1], reverse=True)
        return ranked[:top_k]

    def _normalize_scores(self, results: List[Tuple[Dict, float]]) -> Dict[str, float]:
        """Normaliza scores a rango [0, 1] para poder sumarlos entre sistemas."""
        if not results:
            return {}

        scores = {r[0]['id']: r[1] for r in results}
        max_score = max(scores.values())
        min_score = min(scores.values())

        if max_score == min_score:
            return {k: 1.0 for k in scores}

        return {
            k: (v - min_score) / (max_score - min_score)
            for k, v in scores.items()
        }

    def _fuse_results(
        self,
        semantic: Dict[str, float],
        keyword: Dict[str, float],
        alpha: float
    ) -> Dict[str, Tuple[Dict, float]]:
        """Combina resultados usando weighted sum."""
        all_ids = set(semantic.keys()) | set(keyword.keys())

        fused = {}
        for doc_id in all_ids:
            sem_score = semantic.get(doc_id, 0)
            kw_score = keyword.get(doc_id, 0)
            combined_score = alpha * sem_score + (1 - alpha) * kw_score

            doc = next(
                (d for d in self.vector_store.documents if d['id'] == doc_id),
                None
            )
            if doc:
                fused[doc_id] = (doc, combined_score)

        return fused
```

> **Detalle importante:** `_fuse_results` devuelve un diccionario `{id: (doc, score)}`. Al ordenar hay que usar `.values()`, no `.items()` — si ordenas los items, Python intenta comparar diccionarios cuando hay empate y lanza `TypeError`.

### 2c. Comparar los tres modos de búsqueda

```bash
python -c "
from src.rag.vector_store import SimpleVectorStore
from src.rag.hybrid_search import HybridSearch

store = SimpleVectorStore()
hs = HybridSearch(store)

query = 'PostgreSQL connection timeout'
for nombre, alpha in [('Solo semántica', 1.0), ('Solo keyword', 0.0), ('Híbrida', 0.5)]:
    print(f'--- {nombre} (alpha={alpha})')
    for doc, score in hs.search(query, top_k=2, semantic_weight=alpha):
        print(f'    {score:.3f}  {doc[\"source\"]} §{doc.get(\"section\",\"\")}')
"
```

**Qué observar:** la búsqueda híbrida coloca arriba el chunk del runbook (coincidencia literal) **y** mantiene chunks semánticamente relacionados. Ese es el punto del ejercicio.

---

## Paso 3: Implementar Reranking

### 3a. Instalar el cross-encoder (opcional)

```bash
pip install sentence-transformers    # ya instalado en Tema 10
python -c "from sentence_transformers import CrossEncoder; CrossEncoder('cross-encoder/ms-marco-MiniLM-L-6-v2'); print('modelo descargado')"
```

Si la descarga falla o no tienes red, no pasa nada: el código incluye un `SimpleReranker` heurístico de respaldo.

### 3b. Crear el archivo

```bash
touch src/rag/reranker.py
```

### 3c. Contenido completo de `src/rag/reranker.py`

```python
# src/rag/reranker.py

from typing import List, Dict, Tuple


class CrossEncoderReranker:
    """
    Reranker usando cross-encoder.

    Diferencia clave vs embeddings: el cross-encoder ve la query y el documento
    JUNTOS en la misma pasada, así que captura relaciones que dos vectores
    independientes no pueden. Es más lento, por eso solo se aplica al top-N.
    """

    def __init__(self, model_name: str = "cross-encoder/ms-marco-MiniLM-L-6-v2"):
        try:
            from sentence_transformers import CrossEncoder
            self.model = CrossEncoder(model_name)
        except Exception:
            self.model = None
            print("Warning: CrossEncoder no disponible. Usa SimpleReranker.")

    def rerank(
        self,
        query: str,
        results: List[Tuple[Dict, float]],
        top_k: int = 5
    ) -> List[Tuple[Dict, float]]:
        """Reordena resultados usando cross-encoder."""
        if self.model is None or not results:
            return results[:top_k]

        pairs = [(query, r[0]['text']) for r in results]
        scores = self.model.predict(pairs)

        reranked = [(results[i][0], float(scores[i])) for i in range(len(results))]
        reranked.sort(key=lambda x: x[1], reverse=True)

        return reranked[:top_k]


class SimpleReranker:
    """Reranker basado en heurísticas cuando no hay cross-encoder."""

    def rerank(
        self,
        query: str,
        results: List[Tuple[Dict, float]],
        top_k: int = 5
    ) -> List[Tuple[Dict, float]]:
        """
        Reranking basado en:
        - Presencia de términos exactos de la query
        - Posición del match en el documento
        - Longitud del documento (preferir concisos)
        """
        query_terms = set(query.lower().split())

        scored = []
        for doc, base_score in results:
            text = doc['text'].lower()

            exact_matches = sum(1 for term in query_terms if term in text)
            exact_bonus = exact_matches / len(query_terms) * 0.2

            first_match_pos = min(
                (text.find(term) for term in query_terms if term in text),
                default=len(text)
            )
            position_bonus = (1 - first_match_pos / max(len(text), 1)) * 0.1

            length_penalty = min(0, (500 - len(text)) / 1000 * 0.1)

            final_score = base_score + exact_bonus + position_bonus + length_penalty
            scored.append((doc, final_score))

        scored.sort(key=lambda x: x[1], reverse=True)
        return scored[:top_k]
```

### 3d. Ver el reranking en acción

```bash
python -c "
from src.rag.vector_store import SimpleVectorStore
from src.rag.hybrid_search import HybridSearch
from src.rag.reranker import CrossEncoderReranker, SimpleReranker

store = SimpleVectorStore()
hs = HybridSearch(store)
query = 'cómo reproceso un día que salió mal'

antes = hs.search(query, top_k=5)
print('ANTES del rerank:')
for d, s in antes: print(f'  {s:.3f} {d[\"source\"]} §{d.get(\"section\",\"\")}')

rr = CrossEncoderReranker()
rr = rr if rr.model else SimpleReranker()
print('DESPUÉS del rerank:')
for d, s in rr.rerank(query, antes, top_k=3): print(f'  {s:.3f} {d[\"source\"]} §{d.get(\"section\",\"\")}')
"
```

**Qué observar:** el orden cambia. La sección "Reprocesar un día" debería subir al primer lugar.

---

## Paso 4: Query Expansion

### 4a. Crear el archivo

```bash
touch src/rag/query_expansion.py
```

### 4b. Contenido completo de `src/rag/query_expansion.py`

```python
# src/rag/query_expansion.py

from typing import List


def expand_query(query: str, use_synonyms: bool = True) -> List[str]:
    """Expande la query con términos relacionados."""
    expanded = [query]

    synonyms = {
        "error": ["exception", "bug", "issue", "problem"],
        "function": ["method", "def", "func"],
        "database": ["db", "sql", "postgres", "mysql"],
        "api": ["endpoint", "rest", "http"],
        "test": ["testing", "unittest", "pytest"],
        "config": ["configuration", "settings", "setup"],
    }

    if use_synonyms:
        query_lower = query.lower()
        for term, syns in synonyms.items():
            if term in query_lower:
                for syn in syns:
                    expanded.append(query_lower.replace(term, syn))

    return list(set(expanded))


def decompose_query(query: str) -> List[str]:
    """
    Descompone queries complejas en sub-queries.

    "cómo conectar a postgres y hacer queries" ->
    ["cómo conectar a postgres", "hacer queries"]
    """
    conjunctions = [" y ", " and ", " además ", " también "]

    for conj in conjunctions:
        if conj in query.lower():
            parts = query.lower().split(conj)
            return [p.strip() for p in parts if p.strip()]

    return [query]
```

### 4c. Probar

```bash
python -c "
from src.rag.query_expansion import expand_query, decompose_query
print(expand_query('error de database'))
print(decompose_query('cómo conectar a postgres y reprocesar un día'))
"
```

---

## Paso 5: Pipeline Completo de RAG Avanzado

### 5a. Crear el archivo

```bash
touch src/rag/advanced_pipeline.py
```

### 5b. Contenido completo de `src/rag/advanced_pipeline.py`

```python
# src/rag/advanced_pipeline.py

from typing import List, Dict
from .hybrid_search import HybridSearch
from .reranker import CrossEncoderReranker, SimpleReranker
from .query_expansion import expand_query, decompose_query
from .vector_store import SimpleVectorStore


class AdvancedRAGPipeline:
    """Pipeline RAG avanzado con todas las optimizaciones."""

    def __init__(self, store: SimpleVectorStore):
        self.hybrid_search = HybridSearch(store)

        cross = CrossEncoderReranker()
        self.reranker = cross if cross.model is not None else SimpleReranker()

    def retrieve(
        self,
        query: str,
        top_k: int = 5,
        expand: bool = True,
        rerank: bool = True
    ) -> List[Dict]:
        """Recupera documentos relevantes con todas las optimizaciones."""
        # 1. Query expansion
        queries = [query]
        if expand:
            queries.extend(expand_query(query))
            queries.extend(decompose_query(query))
            queries = list(set(queries))[:5]      # Limitar expansiones

        # 2. Búsqueda híbrida para cada query, deduplicando
        all_results = []
        seen_ids = set()

        for q in queries:
            for doc, score in self.hybrid_search.search(q, top_k=top_k * 2):
                if doc['id'] not in seen_ids:
                    all_results.append((doc, score))
                    seen_ids.add(doc['id'])

        # 3. Reranking
        if rerank and all_results:
            all_results = self.reranker.rerank(query, all_results, top_k=top_k)
        else:
            all_results = sorted(all_results, key=lambda x: x[1], reverse=True)[:top_k]

        # 4. Formatear resultados
        return [
            {**doc, "relevance_score": score, "rank": i + 1}
            for i, (doc, score) in enumerate(all_results)
        ]

    def build_context(
        self,
        results: List[Dict],
        max_tokens: int = 4000
    ) -> str:
        """Construye contexto optimizado para el prompt, respetando un budget."""
        context_parts = []
        current_tokens = 0

        for result in results:
            chunk_tokens = len(result['text']) // 4      # 4 chars ≈ 1 token

            if current_tokens + chunk_tokens > max_tokens:
                break

            context_parts.append(
                f"[Source: {result.get('source', 'unknown')}]\n"
                f"[Section: {result.get('section', '')}]\n"
                f"[Relevance: {result['relevance_score']:.2f}]\n"
                f"{result['text']}"
            )
            current_tokens += chunk_tokens

        return "\n\n---\n\n".join(context_parts)
```

### 5c. Ejecutar el pipeline completo

```bash
python -c "
from src.rag.vector_store import SimpleVectorStore
from src.rag.advanced_pipeline import AdvancedRAGPipeline

p = AdvancedRAGPipeline(SimpleVectorStore())
res = p.retrieve('error de gmv que no cuadra con analytics', top_k=3)
for r in res:
    print(f'#{r[\"rank\"]} {r[\"relevance_score\"]:.3f} {r[\"source\"]} §{r.get(\"section\",\"\")}')
print()
print('--- CONTEXTO PARA EL PROMPT ---')
print(p.build_context(res, max_tokens=500)[:600])
"
```

**Salida esperada:** el chunk de `ERR_GMV_MISMATCH` en el puesto #1 y un contexto formateado con fuente, sección y score.

---

## Paso 6: Actualizar el Skill de Búsqueda

Reemplaza el paso 1 del skill `rag-search` (Tema 10) para que use el pipeline avanzado.

Edita `.claude/skills/rag-search/SKILL.md` y sustituye el bloque de búsqueda por:

```markdown
1. **Recuperación avanzada (híbrida + rerank)**

   \`\`\`bash
   python -c "
   from src.rag.vector_store import SimpleVectorStore
   from src.rag.advanced_pipeline import AdvancedRAGPipeline
   p = AdvancedRAGPipeline(SimpleVectorStore())
   print(p.build_context(p.retrieve('{{query}}', top_k=5)))
   "
   \`\`\`
```

**Verificación:**

```
/rag-search query=ERR_GMV_MISMATCH
```

Claude debe citar el runbook y explicar que el error viene de devoluciones no excluidas.

---

## Verificación Final del Ejercicio

```bash
python -c "from src.rag.keyword_search import BM25; print('1. OK BM25')"
python -c "
from src.rag.vector_store import SimpleVectorStore
from src.rag.hybrid_search import HybridSearch
r = HybridSearch(SimpleVectorStore()).search('PostgreSQL connection timeout', top_k=2)
assert r, 'sin resultados'
print(f'2. OK híbrida -> {r[0][0][\"source\"]}')
"
python -c "from src.rag.reranker import SimpleReranker; print('3. OK reranker')"
python -c "
from src.rag.vector_store import SimpleVectorStore
from src.rag.advanced_pipeline import AdvancedRAGPipeline
res = AdvancedRAGPipeline(SimpleVectorStore()).retrieve('reprocesar un día', top_k=3)
assert res and res[0]['rank'] == 1
print(f'4. OK pipeline -> #{res[0][\"rank\"]} {res[0][\"source\"]}')
"
```

---

## Conexión con Ejercicios Anteriores

- **Tema 10 (RAG Básico):** este tema extiende el mismo `SimpleVectorStore`
- **Tema 6 (Modelos):** el reranker con LLM puede usar Haiku (rápido y barato para clasificar)
- **Tema 7 (Subagents):** un subagent de retrieval devuelve solo el contexto, no los 5000 tokens de chunks
- **Tema 12 (Índices):** cuando el corpus crezca, `SimpleVectorStore` se sustituye por FAISS sin tocar esta capa

## Checklist de Finalización

- [ ] Índice del Tema 10 verificado y `docs/runbook_incidentes.md` indexado
- [ ] `src/rag/keyword_search.py` creado; BM25 encuentra `ERR_GMV_MISMATCH`
- [ ] `src/rag/hybrid_search.py` creado; comparados los 3 modos (alpha 1.0 / 0.0 / 0.5)
- [ ] `src/rag/reranker.py` creado; observado el cambio de orden tras rerank
- [ ] `src/rag/query_expansion.py` creado y probado
- [ ] `src/rag/advanced_pipeline.py` creado y ejecutado end-to-end
- [ ] `build_context()` respeta el budget de tokens
- [ ] Skill `rag-search` actualizado al pipeline avanzado

## Recursos Adicionales

- [BM25 Explained](https://en.wikipedia.org/wiki/Okapi_BM25)
- [Cross-Encoders for Reranking](https://www.sbert.net/examples/applications/cross-encoder/README.html)
- [Reciprocal Rank Fusion](https://plg.uwaterloo.ca/~gvcormac/cormacksigir09-rrf.pdf)

## Tip Avanzado

Implementa **Contextual Compression** para reducir chunks a solo lo relevante antes de meterlos al prompt:

```python
def compress_context(query: str, chunk: str, model: str = "claude-haiku-4-5-20251001") -> str:
    """
    Usa Claude Haiku para extraer solo la información relevante del chunk.
    Recorta 60-80% de los tokens de contexto con pérdida mínima de señal.
    """
    prompt = f"""
    Query: {query}

    Document chunk:
    {chunk}

    Extrae SOLO las frases directamente relevantes para responder la query.
    Si nada es relevante, responde exactamente: NOT_RELEVANT
    """
    response = call_claude(prompt, model=model)
    return response if response.strip() != "NOT_RELEVANT" else ""
```

Alternativa a la weighted sum: **Reciprocal Rank Fusion (RRF)**, que combina por posición en vez de por score, evitando el problema de normalizar escalas distintas:

```python
def rrf_fuse(rankings: List[List[str]], k: int = 60) -> Dict[str, float]:
    scores = {}
    for ranking in rankings:
        for rank, doc_id in enumerate(ranking, start=1):
            scores[doc_id] = scores.get(doc_id, 0) + 1 / (k + rank)
    return scores
```
