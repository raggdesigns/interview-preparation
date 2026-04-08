# Structured outputs & JSON schema

**Interview framing:**

"Structured outputs are how you force an LLM to produce data instead of prose. Under the hood, they're implemented by constraining the model's decoding step so that the only tokens it can emit are ones consistent with a JSON schema you control. The result is that your application gets a validated data structure every time, instead of a string you have to parse hopefully."

> See also the interview-track file for the delivery-ready version: [structured_outputs_why_they_matter.md](../track_interview/structured_outputs_why_they_matter.md). This file is the mechanics-first deep dive.

### Three levels of "structured"

1. **Prompt-based JSON.** You ask the model nicely to return JSON and hope. Works 95% of the time on good models. The remaining 5% is where production bugs live: markdown fences around the JSON, trailing commentary, missing fields, extra fields, wrong types.
2. **JSON mode.** The provider constrains the decoder to produce syntactically valid JSON — no prose, no fences, always parseable. You still have to validate the *shape* yourself, because JSON mode doesn't enforce your schema.
3. **Schema-enforced decoding.** You pass a JSON schema and the provider constrains token sampling to only emit tokens that could complete a document conforming to the schema. Malformed output is impossible by construction.

Always use level 3 when it's available. Level 2 when it isn't. Level 1 only for prototyping.

### How schema-enforced decoding works

At each decoding step, the model produces a probability distribution over every token in the vocabulary. Before sampling, the decoder computes which tokens are *legal* given the current state of the partially-generated document and the schema — and masks the rest to zero probability.

For example, if the schema requires the next field to be an integer and the decoder has already emitted `"age": `, only tokens that can start an integer (`0-9`, `-`) are allowed. Everything else gets zeroed out. Sampling then picks from the legal tokens only.

This is elegant because it's essentially free in terms of quality — the model's preferences are preserved, just filtered — and it makes invalid output structurally impossible.

### What JSON schema features are supported

Support varies by provider, but most production systems handle:

- **Primitive types** — `string`, `integer`, `number`, `boolean`, `null`
- **Arrays** — including `items`, `minItems`, `maxItems`
- **Objects** — including `properties`, `required`, `additionalProperties: false`
- **Enums** — `"enum": ["open", "closed", "pending"]`
- **`oneOf` / `anyOf`** — unions (variable support)
- **String formats** — `date`, `date-time`, `email`, `uri` (hint-level support)
- **Descriptions** — `"description": "..."` on every field (the model reads these)

Things that often *aren't* supported or work unreliably:
- Complex regex patterns
- Recursive schemas
- `$ref` with external references
- `contains`, `if/then/else`
- Custom string formats

When in doubt, keep the schema flat and use the common subset.

### Schema design principles

- **Descriptions are prompts.** The model reads field descriptions. Write them as if they were instructions. `"priority": {"type": "integer", "description": "1 to 5, where 1 is highest priority. Use 3 if unstated."}` produces dramatically better output than a bare integer field.
- **Required where possible.** Required fields anchor the model's reasoning. But don't require fields whose absence is a legitimate answer — that forces hallucination.
- **Enums are contracts.** Any field with a known set of values should be an enum. String fields drift; enum fields don't.
- **Flat beats nested.** A flat schema of 10 fields is easier for the model to fill than a nested schema of 3 objects containing 10 fields total.
- **`additionalProperties: false`** — stop the model from sneaking extra keys into your document. Important for backward compatibility.
- **Nullable where appropriate.** If "unknown" is a valid answer, use `{"type": ["string", "null"]}` instead of making the field required. Forcing a required field when the source lacks the data is an invitation to hallucinate.

### Worked example

Extracting a contact record from an email. Bad schema:

```json
{
  "type": "object",
  "properties": {
    "name": {"type": "string"},
    "phone": {"type": "string"},
    "email": {"type": "string"},
    "company": {"type": "string"},
    "notes": {"type": "string"}
  },
  "required": ["name", "phone", "email", "company", "notes"]
}
```

The model will hallucinate a phone number if the email doesn't contain one, because the field is required. It will invent notes when none are warranted.

Better schema:

```json
{
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "name": {
      "type": "string",
      "description": "The sender's full name as it appears in the email signature or 'From' header."
    },
    "phone": {
      "type": ["string", "null"],
      "description": "Phone number if explicitly present in the email body or signature. Null if not present."
    },
    "email": {
      "type": "string",
      "format": "email",
      "description": "The sender's email address."
    },
    "company": {
      "type": ["string", "null"],
      "description": "Company name from the signature. Null if not mentioned."
    },
    "role": {
      "type": ["string", "null"],
      "enum": ["executive", "manager", "individual_contributor", "other", null],
      "description": "Role category inferred from title in signature. Null if no title is present."
    }
  },
  "required": ["name", "email"]
}
```

Now the model fills what's actually there, nulls what isn't, and the required fields are only the ones guaranteed to be in any email.

### Validation at the boundary

Even with schema-enforced decoding, validate on the way in. Providers have bugs, schema support has edges, and you want your application to degrade gracefully when the contract is violated rather than crashing three layers deep. A thin validation layer at the boundary, using the same schema, catches everything.

For the `agentic-ai` stack specifically:
- **PHP:** `opis/json-schema` or `justinrainbow/json-schema`.
- **TypeScript:** `zod`, `ajv`, or the native schema support in whatever SDK you use.
- **Python:** `pydantic` (not technically JSON schema but close enough and ergonomic).

### Versioning schemas

Schemas are part of your API contract. When they change, downstream code may break. Treat them like any other API surface:

- Version in the schema itself (`"version": "1.2.0"` or a top-level wrapper).
- Log the schema version with every request so you can trace which version produced which data.
- Additive changes are safe; removing fields or tightening types is a breaking change.
- Keep a gold-standard eval set that runs against new schema versions before they ship.

> **Mid-level answer stops here.** A mid-level dev can describe schemas and their syntax. To sound senior, speak to semantic failure and schema evolution ↓
>
> **Senior signal:** where schema-enforced decoding still doesn't save you, and the discipline that prevents silent drift.

### Where schema-enforced decoding still doesn't save you

- **Semantic wrongness inside syntactic correctness.** The schema says `age: integer`. The model returns `age: 35`. The actual age is 27. The schema can't catch that — only eval data can.
- **Hallucination under required-field pressure.** If a required field has no legitimate source value, the model invents one. The fix is schema design (make it nullable) not decoder-level enforcement.
- **Enum confusion under ambiguity.** Asked to classify something that doesn't fit any enum value, the model picks the closest rather than returning an error. Include an `"other"` or `"unclear"` enum value as an escape hatch, or a separate `"confidence": number` field so you can route low-confidence outputs to human review.
- **Refusal collapse.** When the model "wants" to refuse but is schema-constrained to produce a document, it produces a minimal valid document (empty strings, zeros). Add an optional `refusal_reason: string` field so refusals have somewhere to go.
- **Inconsistent enums across model versions.** A new model version may prefer different enum values. Eval-test every schema on every model upgrade.

### The evolution story

Schemas are not write-once. Over time you will:
1. Add fields (safe, backward compatible).
2. Add new enum values (safe for readers that accept unknown values).
3. Tighten constraints (breaking — old responses may now fail validation).
4. Rename fields (always breaking — transition with both names temporarily).
5. Split one field into two (breaking — requires a migration plan).

Handle this with schema versions in the document, migration functions from old → new, and never trusting "we won't change it" as a plan.

### Closing

"So the short version: structured outputs are constrained decoding against a JSON schema. Use the highest enforcement level your provider supports. Design schemas with narrow types, precise descriptions, aggressive enums, and nullable fields for genuinely-unknown data. Validate at the boundary anyway. Version schemas like APIs. And remember that enforcement guarantees syntax, not truth — semantic correctness is still your problem to prove with eval data."
