# Prompt engineering

**Interview framing:**

"Prompt engineering has a bad reputation because the phrase has been associated with magical incantations and LinkedIn guru threads. The real discipline is much more boring and much more useful: it's API design for a stochastic function. You're writing the interface to a non-deterministic component, and like any interface design, the goal is clarity, constraint, and predictable behavior."

### The mental model

Every prompt has three audiences, and good prompts address all three:

1. **The model** — which is a next-token predictor. It responds to structure, specificity, and examples much more than it responds to tone or flattery.
2. **Future you** — who will debug this prompt in six months. Keep it legible; comment it if needed.
3. **Your test suite** — which has to assert on the output. Prompts that produce consistent output are prompts you can actually test.

### The anatomy of a production prompt

A well-structured prompt has clear zones, usually in this order:

1. **Role / identity** — "You are a customer support classifier." Short, specific. Establishes the frame.
2. **Task description** — what the model is supposed to do, in one or two sentences. Precise. "Classify the following ticket into one of the categories below and return the result as JSON."
3. **Constraints and rules** — the must-nots and edge cases. "If the ticket is in a language other than English, return `language_unsupported`. If it contains profanity, classify anyway; do not refuse."
4. **Format specification** — what the output must look like. Preferably a schema, or an example.
5. **Examples (few-shot)** — one to five worked examples. More than five has diminishing returns and eats tokens.
6. **The actual input** — clearly delimited. I use XML tags (`<ticket>...</ticket>`) because models trained on HTML-ish data respond well to them and they're visually unambiguous.

### Techniques worth knowing by name

- **Zero-shot** — just the task, no examples. Works when the task is clear and the model is strong. Cheapest.
- **Few-shot** — include worked examples of input → output. Dramatically improves consistency on classification, extraction, and format-adherence tasks. Choose examples that cover the tricky cases, not just the easy ones.
- **Chain-of-thought (CoT)** — "think step by step before answering". Encourages the model to externalize its reasoning. Produces better answers on multi-step problems at the cost of latency and tokens. Modern reasoning models do this internally; for classic models you still get a lift.
- **Structured reasoning** — a stricter version of CoT: "First, list the relevant facts. Then, identify the category. Then, explain why." The structure constrains the reasoning into a shape you can parse.
- **Self-consistency** — run the same prompt with temperature > 0 multiple times and take the majority answer. Expensive but powerful for high-stakes classification.
- **Delimiters** — XML tags, triple backticks, or section headers. They help the model distinguish instructions from data. Crucial for anything containing user input.

### The principle of constraint

Every word you add to a prompt either **tightens** the distribution of possible outputs or **loosens** it. Good prompts tighten.

- "Write a summary" → loose, output varies wildly.
- "Write a summary in 3 sentences, each under 20 words, focused on the product's main feature" → tight, output is consistent.

The trap: over-constraining produces brittle prompts that fail on edge cases the constraints didn't anticipate. Aim for the loosest prompt that reliably produces the output shape you need.

> **Mid-level answer stops here.** A mid-level dev knows the techniques. To sound senior, speak to the engineering practice around prompts ↓
>
> **Senior signal:** how you version, test, and evolve prompts as part of a real codebase.

### Treating prompts as source code

This is the single most important shift. A prompt is not a magic string. It's part of your system's behavior, same as any other logic. Which means:

- **Version prompts** — store them in files, check them into git. Commit messages explain why the prompt changed.
- **Don't interpolate unsafely.** User input goes into a data section with delimiters, never into the instructions. Prompt injection is exactly what happens when this rule is broken.
- **Keep prompts out of scattered string literals.** I put them in their own directory (`prompts/`) with one file per prompt. Easy to review, easy to diff.
- **Eval every change.** A gold-standard eval set — 50 to 200 labeled examples — that every prompt version runs against. If a change drops the eval score, it doesn't ship.
- **Log the prompt version with every request** so you can trace behavior back to the exact prompt that produced it.

### Common anti-patterns

- **Prompt stuffing.** Adding every rule anyone ever complained about until the prompt is 3000 tokens of contradictions. Rewrite from scratch periodically.
- **Implicit format.** Asking for "a JSON response" without a schema. The model will comply loosely, your parser will break on the 1% that slip through.
- **Example overfitting.** Including examples so specific that the model generalizes from their surface features instead of the concept. If all your few-shot examples mention "Tuesday", the model may think Tuesday is relevant.
- **Mixing instructions and data.** Pasting user content into the middle of the system prompt. Prompt injection paradise.
- **Negative instructions without positive ones.** "Do not use emojis" is weaker than "respond in plain ASCII text only". Tell the model what you *want*, not just what you don't.
- **Tone over substance.** "Please kindly try your best" does nothing measurable. Drop it.

### A small worked example

Bad:

```
You are a helpful assistant. Please classify the user's message and return JSON.
```

Better:

```
You are a ticket classifier for a SaaS support system.

Task: classify the ticket below into exactly one of these categories:
- billing
- technical
- account
- feature_request
- other

Rules:
- Return only a JSON object matching: {"category": "<one of the above>", "confidence": <0.0-1.0>}
- If the ticket mixes multiple categories, pick the dominant one.
- If the ticket is empty or meaningless, use "other" with confidence 0.1.

<ticket>
{user_input}
</ticket>
```

The second version is longer, clearer, more testable, and produces dramatically more consistent output. It's also roughly 30% more tokens — which is the trade-off.

### Closing

"So the short version: prompt engineering is API design under uncertainty. Clear role, precise task, explicit constraints, worked examples when they help, delimited input, versioned prompts, and an eval set that catches regressions. The model is strong; your job is to make it easy for the model to do the right thing."
