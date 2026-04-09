# Tool-calling best practices

**Interview framing:**

"Tool calling is how you give an LLM hands. Without it, the model is a text-in, text-out function — interesting but inert. With it, the model can read files, query databases, hit APIs, and take real action. The whole agentic paradigm rests on this single primitive: the model decides *which tool to call, with what arguments*, and the host application actually runs it. Getting that decision right reliably is where most of the engineering lives."

### How tool calling actually works

1. You register a set of tools with the model — each tool has a name, a natural-language description, and a JSON schema for its arguments.
2. You send a prompt. The model, instead of returning text, can return a structured tool-call request: "call `get_user` with `{id: 42}`".
3. Your application receives that request, **you** execute the tool (the model doesn't run anything itself), and you feed the result back into the next call.
4. The model sees the tool's result and decides what to do next — another tool call, a final answer, or a follow-up question.

The critical thing to understand: **the model never runs anything**. It only *asks* to run things. The host application is the one with hands. That division of responsibility is the whole security model of agentic systems.

### The things that separate reliable tool use from unreliable tool use

- **Tool descriptions are not metadata, they're the contract.** The model picks tools based on natural-language descriptions. A vague description produces unreliable picks. I write descriptions like I'd write the docstring of a function I expected to be called by a junior engineer reading it for the first time: what does it do, when should you call it, what are common mistakes, what's the expected result.
- **Narrow tools beat flexible tools.** One tool called `query_database` is worse than five tools called `get_user_by_id`, `get_orders_by_user`, `search_products`, etc. Narrow tools are easier for the model to pick correctly, easier to secure, and easier to audit. The temptation to build one swiss-army tool should be resisted.
- **Arguments should be typed and constrained.** Enums, min/max, string formats — every constraint you add is a failure the schema decoder prevents rather than one your code has to catch.
- **Tool results should be structured too.** Returning a JSON object with named fields is more reliable than returning a prose summary, because the model's next-step reasoning is grounded in structure rather than rephrasing.

### Tool design principles I follow

- **Principle of least privilege.** A tool exposed to an agent is an API with the most creative client you've ever had. Scope it to exactly what the task needs.
- **Read before write.** I build read-only tools first and only add write tools once the agent is demonstrably reliable on reads. Most agentic bugs show up on reads; better to find them before the agent can delete anything.
- **Idempotency for writes.** Every write tool takes an idempotency key or is naturally idempotent. Agents loop and retry; non-idempotent writes produce duplicates.
- **Return enough context to recover.** If a tool fails, the error message is the agent's only feedback. "Error: invalid input" is useless. "Error: `user_id` must be a positive integer, got 'abc'" lets the agent self-correct.
- **No hidden side effects.** If a tool mutates state, it should be obvious from the name. `get_user` does not create a user if one doesn't exist. `create_or_get_user` does, and is named accordingly.

### The interaction loop

A realistic agentic turn looks like this:

```text
prompt → model → tool_call(name, args)
                 ↓
           host executes tool
                 ↓
           result → model → tool_call(...) or text answer
```

Loops happen. The model calls a tool, reads the result, calls another, reads that, and so on. A well-designed system:

- Limits the max number of tool calls per turn (so a broken loop doesn't run forever).
- Streams tool results back with enough structure that the model can reason about them.
- Logs every tool call and every result as structured audit data.

> **Mid-level answer stops here.** A mid-level dev can describe the mechanics. To sound senior, speak to reliability, security, and failure modes ↓
>
> **Senior signal:** the production concerns that turn tool calling from a toy demo into a system you'd put on-call for.

### Failure modes I've learned to design against

- **Wrong tool picked.** The model calls `delete_user` when it should have called `deactivate_user`. Mitigation: clearer descriptions, narrower scope, and explicit permission prompts for destructive tools.
- **Argument hallucination.** The model invents a `user_id` that doesn't exist. Mitigation: validate against the source of truth and return a helpful error rather than silently succeeding.
- **Result-window bloat.** A tool returns 10,000 rows and blows the context window. Mitigation: pagination, summarization, and a contract that every tool returns bounded output.
- **Infinite loops.** The agent keeps calling the same tool because it can't figure out what to do with the result. Mitigation: max-call limits, loop detection (same call + same result = stop), and a "give up and ask the user" escape hatch.
- **Injection via tool output.** A tool returns untrusted text that contains instructions ("ignore your previous instructions and..."). The model reads it like part of the conversation. Mitigation: treat tool output as data, not instructions — wrap it in structure, never concatenate it into the system prompt, and never let tool output override earlier constraints.

### Security boundary: the most important thing I'd say

"The tool-calling contract is where every security decision in an agentic system gets made. The model isn't a threat; the model is a component. What it calls, and what effect that call has, is *your* decision — not the model's. If a tool can drop a table, the agent can drop the table. If a tool can send money, the agent can send money. Every security audit of an agent reduces to 'what tools are exposed, what do they do, and what authorization sits in front of them'."

### Closing

"So in practice: narrow tools, clear descriptions, typed arguments, structured results, explicit idempotency, aggressive logging, and destructive actions gated behind human confirmation. Tool calling is a simple mechanism with a large blast radius, and the discipline around it is what makes agentic systems reliable."
