# Context and memory management

**Interview framing:**

"The single biggest shift in thinking about LLM-powered systems is realizing that the context window is the *only* form of memory the model has. Everything that feels like memory — conversational history, persona, project knowledge — is an illusion maintained by the application stuffing the right tokens back into the window on every turn. Context and memory management is the engineering discipline around that illusion."

### Context vs memory — the distinction that matters

- **Context** is what's in the window *right now*, this turn, this call. It's ephemeral. When the call ends, it's gone unless something outside the model persists it.
- **Memory** is whatever the application reloads into context next time. It's durable, but only because some external store (a file, a database, a vector store) preserves it and the application decides what to include.

"The model remembers" is always wrong. The correct statement is "the application is putting that information back into the window every turn".

### The context budget

Every model has a maximum window — 128k, 200k, 1M tokens. But *usable* context is almost always smaller than the maximum, for three reasons:

1. **Quality degrades with length.** Models are not uniformly reliable across their whole window. Information in the middle of a long context is more likely to be missed ("lost in the middle" effect). Shorter contexts produce more reliable reasoning.
2. **Cost scales with input tokens.** A maxed-out window is an expensive call, and for long conversations it's expensive *every turn* because the history replays.
3. **Latency follows input size** on the prefill step (though less so than output size). A huge prompt adds up.

Treat the usable window as smaller than the marketing number — maybe 50-70% of it — and aggressively prune the rest.

### What eats context

In roughly descending order of waste:
- **Unsummarized conversation history.** Every turn is replayed in full by default.
- **Tool results.** Unbounded output from a file read or search is the classic window-killer.
- **CLAUDE.md / system prompts bloated with never-needed details.**
- **Few-shot examples left in place long after the model demonstrated it understood the task.**
- **Fixture data** pasted in "just in case".

### Memory layers, from ephemeral to durable

1. **Turn-local.** The current tool result the model is looking at. Disappears at end of turn.
2. **Session-local.** The conversation history. Persists as long as the session runs, at the cost of replaying each turn.
3. **Cross-session memory files.** Notes the application explicitly saves and reloads — `CLAUDE.md`, user memory files, project memory. Durable, but every line costs tokens every session.
4. **External stores.** Vector databases, document stores, SQL databases. The application queries them on demand and injects relevant results into the window. Effectively infinite, at the cost of retrieval complexity.

The right layer depends on *how often* the information needs to be available and *how much of it there is*.

### Strategies for fitting more useful information in less context

- **Summarize old turns.** After N turns, replace the raw history with a compressed summary. You lose exact quotes but keep the essentials.
- **Chunk and retrieve.** Instead of pasting a whole document, embed it, query with the current task, and paste only the top-matching chunks. This is RAG in its minimal form.
- **Reference instead of inline.** Store large artifacts in files; inline only the paths and let the agent read them on demand.
- **Prune tool results.** Trim, filter, paginate. A tool that returns 500 rows should let the caller specify a filter, not dump everything.
- **Structured instead of prose.** JSON is more information-dense than natural language for the same content.
- **Don't repeat what's already said.** If the instruction was given once, don't repeat it every turn unless the model is drifting.

### Memory discipline — the hard part

Writing to memory is easy. Keeping memory *useful* is the hard part:

- **Write selectively.** Not every conversation produces durable knowledge. Most don't. The discipline is recognizing which rare moments produced something worth persisting.
- **Update aggressively.** When a memory becomes wrong, fix it. Stale memory is worse than no memory because the model will act on it confidently.
- **Delete ruthlessly.** Memory that isn't relevant anymore is pure overhead. If a project ends, its memory goes.
- **Scope correctly.** User-level memory (preferences, style) is different from project-level memory (architecture, conventions) is different from task-level memory (in-progress state). Mixing them makes everything harder to maintain.
- **Audit regularly.** Once a month, read your memory files. Delete the cruft. You'll be surprised how much has gone stale.

### Prompt caching — the production optimization

Most providers support caching a stable prefix of the prompt. If your system prompt is 4000 tokens and unchanged across calls, the provider can cache the key-value attention state for that prefix and bill you at a fraction of the normal rate.

Implications:
- **Keep stable prefixes stable.** Any edit to the system prompt invalidates the cache.
- **Put volatile content at the end.** User-specific or turn-specific data should go after the cacheable prefix, not threaded through it.
- **Measure the hit rate.** Caching only pays off if you're actually reusing prefixes. A badly-structured prompt with scattered volatile content caches poorly.

### The "lost in the middle" effect

Empirical finding: information placed in the middle of a long context is more likely to be ignored than the same information placed at the start or end. Models attend more reliably to the edges.

Implications:
- **Put critical instructions near the end.** System prompt at the top, conversation history in the middle, the current user request and critical constraints at the bottom.
- **Don't rely on the model noticing something buried in a 30k-token blob of retrieved context.** If it matters, re-state it in the instructions section.

> **Mid-level answer stops here.** A mid-level dev knows "context is the window". To sound senior, speak to the engineering discipline of managing it as a scarce resource ↓
>
> **Senior signal:** treating context as a budget with a cost function, and the habits that keep long-running systems from drifting.

### Architectural patterns for long-running agents

- **Scratchpad pattern** — the agent maintains a short "current state" document it updates each turn. The scratchpad replaces the full history; the model reasons from state, not replay.
- **Hierarchical memory** — a small working memory (always in context) + a larger retrievable memory (fetched on demand). Modeled after the CPU/RAM/disk hierarchy.
- **Episodic summarization** — periodic compression of past turns into episode summaries. Old episodes become retrievable notes instead of inline replay.
- **Reset points** — explicit "new task" boundaries where old context is dropped. The agent carries forward only what matters.

### Failure modes

- **Context rot.** Long sessions accumulate instructions, corrections, and dead-ends the model keeps re-reading. Quality degrades slowly and imperceptibly. Start fresh sessions for new tasks.
- **Instruction drift.** After many turns, the model's behavior diverges from the original instructions as newer content dominates. Re-anchor critical constraints periodically.
- **Memory poisoning.** A wrong fact written to memory gets re-used confidently. Audits catch this; trust alone doesn't.
- **Context injection.** Untrusted content (tool output, user input) contains fake "instructions" the model follows. Wrap untrusted data in delimiters, never concatenate it into the instruction block.
- **Quiet cache invalidation.** A small change to a stable prompt silently tanks the cache hit rate and blows up costs. Monitor cache metrics.

### Closing

"So the mental model is: context is a finite budget, memory is an illusion, and both of them are engineering problems not model problems. The well-engineered system treats the window as precious, summarizes aggressively, retrieves on demand, caches stable prefixes, and audits durable memory on a schedule. The model is the same across all these strategies; what changes is the discipline of what you put in front of it."
