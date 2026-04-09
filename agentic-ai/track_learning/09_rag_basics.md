# RAG basics

**Interview framing:**

"RAG — retrieval-augmented generation — is the pattern where you search a knowledge base for relevant chunks and paste them into the prompt before asking the model to answer. It's how you give the model access to information that isn't in its training data: product docs, internal wikis, last week's support tickets, your database schema. The single most important mental correction I have to make when people describe RAG is: it's not memory for the model, it's a search engine with an LLM as the UI."

### The pipeline

A RAG system has two phases: an **offline indexing phase** and an **online query phase**.

**Indexing (done ahead of time):**

1. Split each document into chunks.
2. For each chunk, compute an **embedding** — a dense vector representing the chunk's semantic meaning.
3. Store the chunks and their vectors in a **vector database** (pgvector, Qdrant, Weaviate, Pinecone, Chroma, etc.).

**Querying (done per request):**

1. Take the user's question.
2. Embed it with the same embedding model.
3. Search the vector database for the top-K most similar chunks.
4. Construct a prompt containing the chunks + the question.
5. Send it to the LLM and return the answer.

### Why embeddings

An embedding is a vector (typically 512–3072 dimensions) where semantically similar text produces nearby vectors under cosine similarity. "How do I reset my password?" and "I forgot my login" land near each other even though they share no words. That's the whole superpower: you can match by meaning rather than by keyword.

Embeddings come from a separate, smaller model optimized for this job. Use the same model for indexing and querying — mixing models gives you misaligned vector spaces and bad retrieval.

### Chunking — the single biggest lever

How you split documents determines the ceiling on retrieval quality. Bad chunking is unrecoverable; no amount of retrieval wizardry fixes it.

- **Too big** — chunks contain multiple unrelated ideas. Retrieval matches on one idea; the prompt wastes tokens on the others.
- **Too small** — chunks lose surrounding context. The model can't reason about them because key information is in an adjacent chunk that didn't get retrieved.
- **Structurally wrong** — splitting in the middle of a code block, a table, or a logical section produces useless fragments.

What works:

- **Structural chunking.** Split on headings, paragraphs, sentence boundaries, code blocks. Respect the document's natural boundaries.
- **Overlap.** 10–20% overlap between adjacent chunks so context that straddles a boundary is still retrievable.
- **Metadata per chunk.** Store source URL, section, title, timestamp. You'll want these for filtering, display, and debugging.
- **Size tuning.** Start around 500–1000 tokens per chunk and adjust based on eval results, not intuition.

### Retrieval quality > generation quality

If your RAG system produces bad answers, the problem is almost never the LLM. It's almost always retrieval:

- The right chunk exists but didn't rank in the top K.
- The right chunk doesn't exist because chunking destroyed it.
- The query doesn't match because of vocabulary mismatch.
- The vector model is too weak for the domain.

**Measure retrieval in isolation.** Before you look at generation, ask: "For this question, did the correct chunk appear in the top 5?" If no, fix retrieval. If yes and the answer is still wrong, then look at generation.

### Hybrid retrieval — the production default

Pure vector search misses cases where exact matching matters: product SKUs, error codes, specific names. Keyword search (BM25, SQL LIKE, Elasticsearch) is great at these but poor at semantic matching. The right answer is usually both:

1. Run vector search for top N.
2. Run keyword search for top N.
3. Merge and re-rank with a scoring function that combines both.

This is "hybrid retrieval". It almost always beats either alone on real-world queries.

### Re-ranking

Top-K vector search gives you candidates. A **re-ranker** — typically a cross-encoder model — takes those candidates plus the query and scores each more carefully than the initial vector similarity could. Cross-encoders are slower (they process query and candidate together, not as independent embeddings) but much more accurate for the final ranking.

The pipeline becomes: `vector search (fast, recall-oriented) → cross-encoder re-rank (slow, precision-oriented) → top K to prompt`.

### Prompt construction

Once you have the top chunks, constructing the prompt is itself an engineering decision:

- **Delimit chunks clearly.** Use `<chunk source="...">...</chunk>` or similar. The model needs to know where one chunk ends and the next begins.
- **Include metadata.** Source URL, title, timestamp — the model cites better when it sees these, and the user can verify.
- **Order matters.** Higher-ranked chunks earlier. And remember "lost in the middle" — put the most important content at the start or end, not buried.
- **Explicit grounding instruction.** "Answer only using the information in the chunks below. If the answer isn't there, say 'I don't know'." This dramatically reduces hallucination.
- **Require citations.** Ask the model to cite which chunk each claim comes from. This gives you both auditability and a behavioral nudge toward staying grounded.

### When RAG is the wrong tool

- **The corpus fits in the context window.** Just paste it. No vector store needed.
- **The knowledge is per-user and small.** Store it structured and include it directly.
- **The knowledge changes per-request.** Use tool calling — the agent queries a live system — not retrieval over a stale index.
- **You need aggregation or computation.** RAG returns matching passages; it doesn't compute. For "how many tickets this month?" you want SQL, not vector search.

> **Mid-level answer stops here.** A mid-level dev can describe the pipeline. To sound senior, speak to the engineering of retrieval quality, eval, and the failure modes at scale ↓
>
> **Senior signal:** treating retrieval as a search-engineering problem with all the rigor that implies.

### Evaluating a RAG system

You can't improve what you can't measure. A production RAG system needs an eval harness:

- **Retrieval metrics.** Given a query and a known-correct chunk, is it in the top K? Precision@K, recall@K, MRR (mean reciprocal rank).
- **Generation metrics.** Given retrieved chunks and a known-correct answer, does the model produce the right answer? Faithfulness (does the answer stay grounded in the chunks?), answer correctness, citation accuracy.
- **Golden set.** A hand-curated set of questions with known-good chunks and answers. Every retrieval or prompt change runs against the golden set before shipping.
- **End-to-end user feedback.** Thumbs up/down, edit distance from the model's answer to what the user actually used. Hard to interpret but irreplaceable.

### Things that bite at scale

- **Stale indexes.** The corpus changes, the index doesn't. Schedule re-indexing, or use incremental indexing on document changes.
- **Embedding model upgrades.** A new embedding model has a different vector space — you can't mix old and new vectors. Upgrading means re-embedding the entire corpus.
- **Chunk boundary drift.** Changing chunking strategy without re-indexing means new queries hit old chunks badly. Re-index when chunking changes.
- **Cost of retrieval.** Vector search on millions of documents is not free. Approximate nearest-neighbor indexes (HNSW, IVF) trade recall for speed; tune for your budget.
- **Access control.** If different users can see different documents, retrieval must filter by access. Returning chunks the user shouldn't see is a data leak.
- **Long-tail queries.** The eval set covers 80% of the cases. The 20% tail is where RAG systems silently fail. Sample real user queries and check them manually.

### A minimal architecture

```text
User query
    ↓
[Query preprocessing: rewrite, expand, translate]
    ↓
[Hybrid retrieval: vector + keyword, top N candidates]
    ↓
[Re-rank: cross-encoder, top K winners]
    ↓
[Access control filter]
    ↓
[Prompt construction with grounding instruction]
    ↓
[LLM call]
    ↓
[Answer with citations]
```

Each stage is independently tunable. Each stage has its own failure modes. Each stage is worth measuring on its own.

### Closing

"So RAG is a search engineering problem first and an LLM problem second. Chunk well, retrieve with hybrid search, re-rank the candidates, construct grounded prompts, and measure retrieval quality before you blame the model. When it works, it gives you LLMs over any corpus you can embed. When it doesn't, it's almost always because someone skipped the search engineering."
