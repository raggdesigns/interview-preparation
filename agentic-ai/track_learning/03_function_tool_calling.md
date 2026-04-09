# Function / tool calling

**Interview framing:**

"Tool calling is the mechanism that lets an LLM decide to invoke code. It's the bridge between 'model that writes text' and 'agent that does things'. Mechanically it's very simple — structured output with a specific shape — but the design discipline around it is what separates a reliable agentic system from a chaotic one."

> See also the interview-track file for the delivery-ready version: [tool_calling_best_practices.md](../track_interview/tool_calling_best_practices.md). This file is the deeper, mechanics-first view.

### The protocol

Tool calling is structured output with a convention. You register tools with the model, each described by:

- **Name** — a short identifier the model will use when calling.
- **Description** — a natural-language explanation of what the tool does and when to use it.
- **Input schema** — a JSON schema describing the arguments.

When the model decides to call a tool, instead of returning a text message it returns a structured object:

```json
{
  "tool": "get_user",
  "arguments": { "id": 42 }
}
```

The host application (not the model) executes the tool, captures the result, and sends it back into the next turn as a tool-result message. The model reads the result and decides what to do next — another tool call, a user-facing answer, or a follow-up question.

### The key realization

The model does not run code. It emits a request to run code, and your application decides whether and how to run it. This is the entire security model of agentic systems, and it's why "the agent deleted my database" is always a permissions problem, not a model problem.

### How the model decides which tool to call

It's still next-token prediction under the hood. The model sees:

- The user's request
- The list of tools with their names and descriptions
- The conversation so far

...and decides — by generating tokens — which tool (if any) to call and what arguments to pass. The tool descriptions are part of the prompt; the model reads them the same way it reads any other instructions. This has an important consequence: **your tool descriptions are prompt engineering**. A vague description produces unreliable selection. A precise description with examples produces reliable selection.

### Parallel tool calls

Modern models can emit multiple tool calls in a single turn when the calls are independent. A request like "show me user 42's profile and their last 10 orders" might produce two parallel calls: `get_user(42)` and `get_orders(42, limit=10)`. The host executes both (ideally in parallel), collects the results, and sends them back together.

This is a meaningful latency win, and worth designing for explicitly. Tools whose results don't depend on each other should be structured so the model can parallelize them, and your execution layer should actually run them concurrently rather than serially.

### Multi-turn tool use — the agentic loop

A typical agentic interaction is:

```text
user: "Send a summary of yesterday's errors to the on-call channel"

turn 1: model calls query_logs(start=yesterday, level=error)
turn 2: model reads 47 errors, calls summarize_errors(errors=[...])
turn 3: model calls post_to_channel(channel="oncall", message=<summary>)
turn 4: model responds to user: "Done, posted summary of 47 errors."
```

Each turn is one model call. The whole sequence is one user-visible interaction. The loop terminates when the model decides to return a text message instead of another tool call — or when the host enforces a limit.

### Guard rails the host needs to enforce

- **Maximum tool calls per interaction.** Agents can loop. Cap it.
- **Loop detection.** Same call + same arguments + same result = probably stuck. Terminate.
- **Timeout per tool call.** No single tool call blocks the loop forever.
- **Permission prompts for destructive actions.** Some tools require human approval regardless of what the model decides.
- **Auditing.** Every tool call is logged with arguments, result, timestamp, and the user context that triggered it.

### JSON schema tips for tool arguments

- Use `enum` for any field with a known set of values.
- Use `format` (`date`, `email`, `uri`) where applicable — it gives the model a hint even when the host doesn't strictly validate it.
- Use `minimum`/`maximum` on numbers with known ranges.
- Make optional fields genuinely optional. Don't require `notes: string` when empty notes are fine.
- Add `description` to every field. The model reads field descriptions and they significantly improve argument quality.
- Prefer flat structures over deeply nested ones. The model fills flat structures more reliably.

> **Mid-level answer stops here.** A mid-level dev knows the mechanics. To sound senior, speak to tool design as API design, and the failure modes of agentic loops ↓
>
> **Senior signal:** treating tool surface area as a product decision, and the discipline around agentic loops.

### Tool design is API design, with extra constraints

The standard API design rules apply — clear naming, narrow responsibilities, consistent argument styles — but tool design has additional constraints because the client is a language model:

- **Names should describe intent, not implementation.** `get_active_users_modified_since` is better than `query_users_v2`. The model picks on meaning, not on memorized APIs.
- **Fewer arguments beat more arguments.** Three-argument tools are much more reliably called than seven-argument tools. If you have many optional parameters, consider splitting into multiple narrower tools.
- **Results should be structured.** Return a JSON object with named fields, not a prose summary. The model will re-interpret structured data more accurately on the next turn.
- **Results should be bounded.** A tool that returns "all matching rows" is a context-window bomb. Always paginate or cap.
- **Error messages are a UI.** When a tool fails, the error message is the only feedback the model gets. "Error: bad input" teaches it nothing. "Error: `user_id` must be a positive integer; got 'abc'. Did you mean to use `email` instead?" lets the model recover.

### Failure modes in the wild

- **Argument hallucination** — the model invents a user ID that doesn't exist. Mitigation: validate and return a useful error, don't silently proceed.
- **Tool confusion** — the model picks `delete_user` when the user asked to "remove them from the list". Mitigation: narrower tools, clearer descriptions, and destructive operations behind explicit confirmation.
- **Result misinterpretation** — the tool returns `{"count": 0}` and the model reports "found many results". Mitigation: structured results with unambiguous field names (`result_count: 0`, `items: []`).
- **Tool-output prompt injection** — a tool returns untrusted text that contains instructions. The model treats them as instructions. Mitigation: wrap tool output in a data section, never let tool output override system constraints.
- **Runaway loops** — the model keeps calling tools because nothing produces a clear "done" signal. Mitigation: loop caps, explicit success criteria, and an escape-hatch tool like `ask_human` when the model is stuck.

### Mental model to leave with

"Tool calling is structured output with side effects. Everything you know about structured output applies — schemas matter, descriptions matter, errors matter — plus everything you know about API design for least privilege and auditability. The hard part is not the mechanism; it's the discipline of designing tools the model can use reliably and safely."

### Closing

"So: tools are declared with names, descriptions, and schemas. The model requests tool calls but never executes them. The host runs the tool and feeds the result back. The loop terminates when the model returns text. Everything interesting happens in how you design the tools, not in how you wire them up."
