# Advanced agentic patterns — elevator answers

This file is a set of **60-second answers** for the advanced patterns interviewers ask about. Each is short enough to deliver under pressure, precise enough to sound senior, and structured so you can expand on any section if the follow-up comes.

---

## RAG — retrieval-augmented generation

**The 60-second answer:**

"RAG is how you give a model access to knowledge that isn't in its training data — product docs, your company's wiki, last week's support tickets. The flow is simple: you embed a corpus of documents into a vector database ahead of time, and at query time you embed the user's question, find the most similar chunks, and paste them into the prompt. The model answers using the retrieved chunks as context.

The mental model I use: RAG is not 'memory for the model' — it's *a search engine with an LLM as the UI*. Everything you know about search — ranking quality, chunking strategy, stale indexes, query reformulation — applies directly. The hard problems aren't in the LLM; they're in retrieval quality. If you feed a model the wrong three chunks, it gives you a confidently wrong answer.

The things that matter in production: chunk size (too big wastes context, too small loses context), hybrid retrieval (vectors plus keyword search — vectors alone miss exact-match cases), re-ranking with a cross-encoder, and aggressive eval on retrieval quality *before* you even look at generation quality. Most 'RAG isn't working' complaints are retrieval complaints."

**If asked "when do you *not* use RAG":** "When the corpus is small enough to fit in the context window, when the knowledge changes per-request (just put it in the prompt), or when you need real-time data from a live system — for that you want tool calling, not retrieval."

---

## Self-critique / critique loops

**The 60-second answer:**

"Self-critique is the pattern where a model generates an answer, then a second model call — or the same model with a different prompt — reviews the answer and produces a revised version. The structure is generate → critique → revise. It's surprisingly effective for tasks where errors are obvious in hindsight but hard to avoid during generation — code reviews, fact-checking, catching missed requirements.

The reason it works: generation and evaluation use different mental moves. A model asked to 'write code to solve X' is optimizing for plausible output. The same model asked 'does this code correctly solve X?' is optimizing for correctness against a spec. Separating the two passes gives you a second chance with a different objective.

The trade-off is cost and latency — you've at least doubled both — and it can converge on polished-sounding output that's *still* wrong if the critique step shares the same blind spots as the generation step. I use it for high-stakes tasks where the cost of a wrong answer is much higher than the cost of a second call. I don't use it for throwaway work."

**If asked about variations:** "Multi-model critique — generate with one model, critique with another — reduces the shared-blind-spot problem. Adversarial prompting in the critique step ('find three things wrong with this') produces more useful feedback than generic 'is this good?'"

---

## Hooks (in Claude Code specifically, but the concept generalizes)

**The 60-second answer:**

"Hooks are shell commands the harness runs automatically on specific events — before a tool call, after a file edit, on session start, on user prompt submit. The important property is that hooks run in the harness, not the model. The model can't skip them, can't talk them out of running, can't be prompt-injected into disabling them. That makes hooks the natural place for safety rails and policy enforcement.

The canonical uses: pre-edit hooks that block edits to sensitive files, post-edit hooks that run linters and fail if the output is invalid, pre-commit hooks that run tests before the agent is allowed to commit. You're basically giving the agent a pair of guardrails that don't depend on the agent's cooperation to work.

The trap is over-hooking — turning every mild concern into a shell script until the agent can't breathe. Hooks are for hard invariants (this must never happen) not soft preferences (this should usually happen). Soft preferences belong in the prompt or the memory file."

---

## Cost optimization

**The 60-second answer:**

"Cost in LLM systems is dominated by tokens — specifically input tokens, because conversation history compounds. The single biggest lever is context discipline: shorter prompts, shorter histories, aggressive summarization of old turns, and not shoving entire files into the window when a relevant snippet would do.

After context discipline, the next lever is model routing — use a cheap fast model for easy classifications and cheap extractions, reserve the expensive model for the hard reasoning. A well-designed pipeline uses three or four different models at different stages, not one expensive model for everything.

Caching is underrated. Most providers now support prompt caching, where a repeated prefix (a long system prompt, a fixed schema) is cached server-side and billed at a fraction of the normal rate. If your system prompt is 4000 tokens and stable, caching it can drop the per-call cost by an order of magnitude.

The mistakes I see most often: people measure cost per request instead of cost per unit of delivered value; people use the biggest model because 'it's more accurate' without measuring whether the accuracy delta justifies the cost; people build RAG pipelines that retrieve way more context than the generation step actually uses."

---

## Tool mocking for tests

**The 60-second answer:**

"Testing agentic code has the same problem as testing any I/O-heavy code: the real dependencies are slow, expensive, and nondeterministic. The solution is mocking the tools, not the model. You stub out `get_user` to return a fixture, stub `send_email` to record the call, and let the real LLM run against mocked tools. That way you test the agent's reasoning and tool-selection behavior without hitting production systems.

The more interesting question is what you're *asserting on*. You can't assert on exact text — the model is nondeterministic. You assert on properties: which tools got called, in what order, with what arguments; did it terminate; did it produce structured output matching the schema. Think of it like testing a router, not testing a function."

---

## A/B testing prompts and agents

**The 60-second answer:**

"Prompts are source code, and like any source code they need regression testing when you change them. A/B testing prompts is the same idea as A/B testing a feature: run the old version and the new version side by side on a held-out eval set, measure the metrics you care about, and only ship the change if it wins.

What 'winning' means depends on the task. For classification: accuracy against labels. For extraction: field-level F1. For generation: a rubric scored by another LLM, or by humans if you can afford it. The mistake people make is shipping prompt changes based on 'it looks better on three examples I tried' — which is exactly the mistake they'd never make with a code change.

The production version of this is keeping prompts versioned, logging which version handled each request, and running continuous eval against a gold set so drift is caught before users see it."

---

## Closing thought for any of these

"All of these patterns share a theme: they're ways of turning a nondeterministic, hallucination-prone next-token predictor into a component you can rely on. None of them fix the underlying model; they *constrain* it. And that's the meta-principle of production agentic systems — reliability comes from constraint, not from the model being smarter."
