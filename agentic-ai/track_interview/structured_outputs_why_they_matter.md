# Structured outputs — why they matter

**Interview framing:**

"Structured outputs are the single biggest step from 'LLM demo' to 'LLM in production'. A model that emits free-form prose is a toy; a model that emits JSON matching a schema you control is a component you can actually build a system around. The difference isn't cosmetic — it's the difference between parsing regexes out of English and calling a typed function."

### The problem structured outputs solve

Raw LLM output is a string. If you want to do anything programmatic with it — route it, store it, act on it, feed it to another service — you have to parse it. And parsing natural language is exactly the thing natural language is bad at being parsed from. You end up writing brittle regex, the model adds a friendly preamble on one call out of fifty, and your pipeline breaks at 3 a.m.

Structured outputs flip the contract: instead of "produce a helpful answer", the instruction becomes "produce a JSON document that validates against this schema". The model's job is no longer to be eloquent; it's to fill slots.

### How they work under the hood

There are three mechanisms providers use, roughly in increasing order of reliability:

1. **Prompt-only** — you describe the schema in the prompt and ask nicely. Works, mostly. Fails on edge cases, long schemas, or when the model decides to wrap the JSON in markdown fences.
2. **JSON mode** — the provider constrains the decoder to only produce valid JSON. You still have to validate the *shape* yourself.
3. **Schema-enforced decoding** — you pass a JSON schema and the provider constrains the model's token sampling to only emit tokens that could lead to a valid document. This is the gold standard: malformed output is impossible by construction, because the sampler refuses to pick an invalid token.

Under the hood, schema-enforced decoding works by masking the probability distribution at each step: any token that would make the document invalid gets its probability zeroed out before sampling. It's elegant and it's what you want in production.

### What this unlocks

- **Tool calling.** A "tool call" is just a structured output where the schema describes the tool's arguments. Same machinery.
- **Extraction pipelines.** Turning unstructured input (emails, PDFs, transcripts) into structured records you can write to a database.
- **Routing and classification.** "Which of these categories does this ticket belong to?" returns an enum value, not a paragraph.
- **Reliable chaining.** The output of one LLM call becomes the typed input of the next, without a parsing step between them.
- **Testable behavior.** You can assert on schema validity and field values, not on natural-language similarity.

### How I actually use them

- I **design the schema first**, before the prompt. The schema is the contract; the prompt is the instruction. Schema-first forces me to specify what I actually want.
- I **keep schemas narrow.** A schema with 40 optional fields is a schema the model will fill incorrectly. Fewer fields, tighter types, required where possible.
- I **use enums aggressively** for any field with a known set of values. `"status": "string"` is an invitation for drift; `"status": "open" | "closed" | "pending"` is a constraint.
- I **add descriptions to every field.** The model reads them. A field called `priority` with the description "1 = highest, 5 = lowest, default 3 if unstated" produces dramatically better output than a bare `priority: integer`.
- I **validate on the way in**, even when schema-enforced decoding is on. Belt and suspenders. The cost is negligible; the benefit is catching provider bugs.

> **Mid-level answer stops here.** A mid-level dev would describe "it returns JSON". To sound senior, speak to the failure modes and the design discipline ↓
>
> **Senior signal:** where structured outputs still go wrong, and how you design schemas for reliability.

### Where they still go wrong

- **Semantic errors inside syntactic correctness.** The document parses, the fields are the right types, and the *content* is still wrong. Schema-enforced decoding constrains structure, not truth. Your validation layer needs semantic checks, not just type checks.
- **Over-specified schemas.** If you make every field required and the model genuinely can't fill one, it will hallucinate a value rather than refuse. Make optional fields optional; explicitly allow `null` where "unknown" is a legitimate answer.
- **Schemas too large for the context budget.** Huge schemas eat tokens and dilute the prompt. If a schema is big, split the task into multiple smaller calls.
- **Refusal-mode collapse.** When asked to do something it shouldn't, a model under schema constraints may return a minimal valid document (empty strings, zeros) rather than an explicit refusal. Include a `refusal_reason` field if the task has that risk.
- **Enum drift across model versions.** A new model version may prefer different enum values even for the same prompt. Version your schema, pin your model, and treat upgrades as behavior changes worth testing.

### Design principles I follow

- **Smallest viable schema.** Every field you add is a potential hallucination site.
- **Required fields for ground-truth data, optional for derived.** If the source doesn't contain the information, don't make the model invent it.
- **Descriptions are prompts.** Treat every field description as a mini-prompt. Be precise.
- **One document per conceptual unit.** Don't cram multiple tasks into one schema; chain multiple calls with small schemas.
- **Version schemas like APIs.** Because that's what they are.

### Closing

"So the short version: structured outputs turn an LLM from a writer into a function. Once you adopt them you stop thinking in terms of 'how do I parse this answer' and start thinking in terms of 'what's the type signature of the call I'm making'. That shift is the single most important move from prototype to production."
