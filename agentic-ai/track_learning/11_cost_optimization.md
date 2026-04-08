# Cost optimization

**Interview framing:**

"Cost in LLM-powered systems is dominated by tokens, and token spend grows in ways that are unintuitive if you think about it as 'per request'. A single user conversation isn't one call — it's N calls where each call replays the whole history so far, so costs grow quadratically with session length. A good LLM system engineer has a mental model of where the tokens are going and which knobs actually move the bill."

### The cost anatomy

Every LLM call has two costs:
- **Input tokens** (prompt tokens) — everything you send in.
- **Output tokens** (completion tokens) — everything the model generates.

Output tokens are usually priced several times higher than input tokens, but for most real workloads the *volume* of input tokens dominates, so input costs end up larger than output costs in absolute terms. This is the first surprising fact: most of your bill is coming from stuff the model *read*, not stuff it *wrote*.

### Where the tokens go

1. **Conversation history.** Each turn replays every prior turn. A 20-turn conversation sends 20× more tokens on the last turn than the first.
2. **System prompts.** Long static prompts attached to every call.
3. **Retrieved context.** RAG that returns big chunks, or returns too many chunks.
4. **Tool results.** Unbounded output from a file read or search pasted into the next turn.
5. **Few-shot examples** left in place when they're no longer needed.
6. **Structured output schemas** — large schemas cost tokens in the prompt.
7. **Completions that ramble.** Output verbosity that doesn't need to be there.

Rank ordering your actual bill by these categories is the single most useful thing you can do before optimizing.

### The levers, in order of impact

#### 1. Prompt caching

Most providers now support caching a stable prefix of the prompt. If the first 4000 tokens of every call are identical — system prompt, instructions, few-shot examples — the provider can cache them and bill at a fraction of the normal rate (often 10-25% of the uncached price).

**Rules to actually benefit:**
- Put stable content at the start. Anything that changes per-request goes after.
- Don't edit the cacheable prefix. Small edits invalidate the cache and you pay full price.
- Measure cache hit rate. If it's low, your prompt structure is wrong.

This is often the single biggest win for any high-volume system. Do it first.

#### 2. Model routing

Use a cheap fast model for easy work, reserve the expensive model for the hard work. A classification task might be fine with Haiku or Gemini Flash; a complex debugging task needs Opus or equivalent.

A well-designed pipeline has 3-5 different models across different stages. The temptation to use one top-tier model for everything is expensive and usually unnecessary. Start with the cheap model, measure quality, only escalate when the data shows you need to.

#### 3. Context discipline

Every token in the prompt is billed every turn. Shortening prompts and histories compounds across calls.

Tactics:
- **Summarize old turns.** After N turns, replace the raw history with a compressed summary.
- **Drop tool results** once their information has been extracted into the conversation state.
- **Prune retrieved context.** Return the top 3 chunks instead of the top 10.
- **Trim system prompts.** Every sentence should earn its place. Re-read them periodically and delete.
- **Reference instead of inline.** Store large artifacts in files and reference them by path; let the agent read them on demand when needed.

#### 4. Output control

Output tokens are priced higher per unit. Reducing output length has outsized impact.

Tactics:
- **Request concise answers explicitly.** "Respond in under 100 words" works.
- **Use structured output** instead of prose. JSON is denser than explanation.
- **Stop sequences.** Define tokens that halt generation early.
- **Max tokens.** Cap output length as a safety net.

#### 5. Batching and parallelism

If you have 1000 classification tasks, don't make 1000 sequential calls. Many providers offer batch APIs at reduced cost with higher latency — exactly the trade-off that's right for offline work. For online work, parallelize independent calls so you're not paying latency multiple times.

#### 6. Embedding and retrieval caching

Embedding the same query twice is pure waste. Cache embeddings by input. For RAG systems with repetitive queries, this is a meaningful saving.

#### 7. Avoiding unnecessary agentic loops

The most expensive failure mode is an agent that loops a few extra times because the task wasn't well specified. Each loop is a full call at the current context size. Tightening task definitions so the agent finishes in 3 tool calls instead of 7 often dwarfs every other optimization.

### Cheap vs expensive — a mental framework

I categorize LLM calls into three tiers:

- **Cheap** — classification, extraction, short summaries, simple yes/no judgments. Use the smallest model that works.
- **Medium** — multi-paragraph writing, moderate reasoning, structured output from messy input. Mid-tier model.
- **Expensive** — agentic loops, long reasoning chains, complex code generation, sensitive high-stakes output. Top-tier model.

A well-designed system has a lot of cheap calls, some medium calls, and few expensive calls. If your logs show you're burning the expensive model on cheap tasks, that's a misrouting problem and fixing it pays back immediately.

### Measuring before optimizing

Don't optimize blind. Instrument:

- Tokens per request, split by call site and model.
- Cache hit rate per cacheable prompt.
- Cost per user action (sign-up, ticket resolved, query answered) — this is the business metric that matters.
- Distribution of request sizes. The long tail is usually where runaway costs live.
- Agentic loop depth distribution — how many tool calls per interaction on average and p99.

When you see the numbers, the optimizations often prioritize themselves. It's common to find one misbehaving code path producing 30% of total spend.

> **Mid-level answer stops here.** A mid-level dev can list optimization tactics. To sound senior, speak to cost as a continuous engineering concern, not a one-time fix ↓
>
> **Senior signal:** treating cost as a first-class SLO, with monitoring, budgets, and tradeoff discipline.

### The discipline

- **Cost is a metric, not a crisis response.** Track it every day, not after a surprise bill.
- **Budgets per feature.** Every new LLM-powered feature has a target cost per action. Ship with instrumentation, check against the target.
- **Alerts on anomalies.** Spikes are almost always a bug or a regression, not real demand. Catch them early.
- **Regression testing for cost.** Prompt changes can silently double token usage. A CI step that flags cost-per-test-case drift is worth building.
- **Trade-off literacy.** Sometimes quality justifies a 3× cost bump; sometimes it doesn't. You can only know by measuring quality against cost, not by preferring one axis.

### Common anti-patterns

- **Default to the biggest model.** "It's more accurate" without measuring how much more. Often the delta is negligible and the cost is 10×.
- **Infinite memory.** Replaying every turn forever instead of summarizing. Session cost grows quadratically and nobody notices until the bill arrives.
- **RAG with huge chunks and huge K.** Pasting 50,000 tokens of context into every call because "more information is better". Usually it isn't.
- **No cache hit metrics.** Claiming caching is on while actually invalidating the cache on every call.
- **Over-critiquing.** Self-critique loops on tasks that don't need them, doubling or tripling every request cost for marginal quality gain.
- **Verbose output.** No max-tokens, no format constraint, no instruction to be concise. Model rambles, you pay.

### Rule-of-thumb numbers to keep in your head

(These shift constantly but the *ratios* stay useful.)

- Input tokens are cheap relative to output tokens — typically 3-5× cheaper.
- Cached input is much cheaper than uncached — typically 10-25% of the uncached price.
- Top-tier models cost 10-30× the budget-tier models of the same family.
- A 20-turn conversation without summarization can easily cost 100× a single-turn conversation on the final turn alone.

### Closing

"So the summary: cost is dominated by input tokens, driven by conversation history and context bloat, and governed by levers in roughly this order — prompt caching, model routing, context discipline, output control, batching, retrieval caching, and loop discipline. The single most important thing is measuring where the tokens actually go, because intuition is wrong about half the time and the surprising code paths are usually where the money is."
