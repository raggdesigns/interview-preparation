# LLM fundamentals

**Interview framing:**

"Before you can talk intelligently about agents, prompts, or tool-calling, you need a working mental model of what a large language model actually *is* — because almost every counterintuitive failure mode of these systems traces back to people forgetting the basics. An LLM is a function that takes a sequence of tokens and returns a probability distribution over the next token. Everything else — agents, tools, memory, RAG — is wiring on top of that single operation."

### The operational model in one paragraph

A model takes an input sequence, tokenizes it into integer IDs, runs it through a transformer, and emits a probability distribution over the entire vocabulary for the next token. A sampler picks a token from that distribution. That token is appended to the input, and the loop runs again. Everything the model "knows", every instruction it "follows", every tool it "decides" to call — all of it happens inside this next-token-prediction loop. There's no memory between calls, no planning module, no hidden state surviving the end of a request. The only thing that exists is the context window.

### Key primitives

#### Tokens

The model doesn't see characters or words — it sees tokens, which are subword fragments produced by a tokenizer. A rough rule of thumb: 1 token ≈ 4 characters of English, or ¾ of a word. Non-English text, code, and numerics tokenize worse (more tokens per character). This matters because:

- You're billed per token, not per character.
- The context window is measured in tokens, not words.
- Weird tokenization causes weird failure modes (e.g. models miscounting letters in a word because the word is a single token).

#### Context window

The maximum number of tokens the model can see at once, input plus output. Modern models span 128k, 200k, 1M tokens. The context window is the **only** form of memory the model has during inference. Anything outside the window doesn't exist as far as the model is concerned. "Conversational memory" is an illusion maintained by the client: the client replays the whole conversation into the window on every turn.

Implication: long conversations cost more per turn (the whole history is re-sent), and eventually run out of room.

#### Temperature and sampling

After the model emits a distribution, a sampler picks a token. Temperature controls how sharply the distribution is peaked:

- **Temperature 0** — always pick the highest-probability token. As close to deterministic as you get, useful for extraction, classification, structured output.
- **Temperature 0.7–1.0** — typical "creative" setting. The same prompt will give different answers each time.
- **Temperature > 1** — flatten the distribution, producing weirder output. Rarely useful in production.

Other sampling knobs: `top_p` (nucleus sampling — consider only tokens whose cumulative probability is above a threshold), `top_k` (consider only the k most likely tokens). In practice you use either temperature or top_p, not both.

#### Determinism (and why it's a lie)

Even at temperature 0, LLM output is not guaranteed to be byte-identical across runs. Floating-point non-determinism, batching differences on the provider's side, and model version drift all leak in. Treat "deterministic" as "mostly the same" and always write tests that assert on *properties* of the output, not exact strings.

#### Logprobs

Most APIs can return the log-probability of each emitted token, and often the top-N alternatives. This is the closest thing you get to a confidence score — but it's a confidence score for *this specific token*, not for the correctness of the answer. A model will confidently produce plausible nonsense with high logprobs. Use logprobs for pipeline decisions (classification thresholds, routing), not as a truth signal.

> **Mid-level answer stops here.** A mid-level dev knows "it predicts the next token". To sound senior, you need to speak to the consequences of that prediction model on real systems ↓
>
> **Senior signal:** the failure modes and architectural decisions that fall out of how LLMs actually work.

### Consequences for system design

- **No memory between requests.** If you want the model to remember something, you put it in the context window. This is why every chat app replays the whole conversation, why RAG exists, why memory files exist. "The model forgot" is always a context-window problem.
- **Cost scales with context, not just requests.** A 50-turn conversation isn't 50× a single turn's cost — it's roughly quadratic, because each turn sends more history than the last. Trimming, summarizing, or chunking old history is a real engineering concern at scale.
- **Latency scales with output length, not input length.** Reading the prompt is fast (parallelizable across tokens); generating output is serial (one token at a time). If your latency is bad, shortening the prompt barely helps — shortening the response a lot does.
- **Hallucination is not a bug, it's the default mode.** The model is a probability function. It outputs the most likely next token given the input. When the input doesn't constrain the output enough, "most likely" drifts into "plausible-sounding but wrong". The fix is constraint: retrieval (RAG), tools, structured outputs, strict prompts — anything that tightens the distribution.
- **The same input can produce different outputs.** This means tests need tolerance, retries are safe for read-only operations, and any write operation driven by LLM output needs idempotency.
- **Prompts are part of your source code.** Treat them with the same discipline: versioned, code-reviewed, tested. A silent prompt tweak can change system behavior as much as a code change.

### What to say when asked about newer models

"The important thing is the capability envelope, not the marketing. Newer models tend to extend the context window, improve reasoning on complex tasks, and reduce hallucination on benchmarks — but they don't change the fundamentals. It's still next-token prediction, it still has no persistent memory, and it still needs constraint to be reliable. The architectural patterns you build around a model stay the same across generations; what changes is what you can get away with inside those patterns."

### Closing

"So the short version: an LLM is a stateless probability function over tokens. Memory is an illusion maintained by replaying context. Determinism is a target you aim at but never hit. Hallucination is the natural state; correctness is something you engineer. Once that mental model is solid, every higher-level concept — agents, tools, RAG, MCP — makes sense as a way to bend a next-token predictor into something useful."
