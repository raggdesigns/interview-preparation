# Sub-agents and delegation

**Interview framing:**

"A sub-agent is a separate agent session spawned from a parent session, with its own context window and its own task. The parent dispatches work, the sub-agent runs, and only the sub-agent's *final report* returns to the parent. It's the agentic equivalent of 'shelling out to a helper process' — and like shelling out, its value is in what it keeps *out* of the caller's context, not just what it produces."

### The core idea: context isolation as a resource

Context windows are finite and expensive. Every token the parent reads costs money and pushes earlier tokens toward the edge where they start getting lost. If the parent has to read 40 files to answer one question, those 40 files bloat the parent's context for the rest of the session.

A sub-agent solves this by running the exploration in a separate context and returning a small summary. The parent sees "here's what you asked about, in 200 tokens" instead of "here are 40 file contents totaling 30,000 tokens". The parent's conversation stays clean; the sub-agent's context is discarded at the end of its run.

Think of it as *bounded exploration*. The parent pays the cost of the summary; it doesn't pay the cost of the search.

### When to dispatch a sub-agent

- **Codebase exploration** — "find all call sites of function X", "how does feature Y actually work end to end".
- **Independent parallel work** — multiple unrelated changes that don't share state. Dispatching in parallel compresses wall time.
- **Heavy research** — reading long docs, scanning many files, evaluating multiple options.
- **Fresh-eyes review** — a code review by a sub-agent that doesn't know how the implementation was built is more likely to notice what's actually wrong.
- **Throwaway experiments** — trying an approach you might reject; the failed attempt doesn't pollute the main session.

### When NOT to dispatch a sub-agent

- **The task needs information that's already in the parent's context.** Re-loading it wastes tokens and risks inconsistency.
- **The task is short.** A one-tool-call task isn't worth the coordination overhead.
- **The task's output is the full artifact.** Sub-agents pass back summaries; if you need the whole 4000-line generated file, you're not really benefiting from isolation.
- **You need tight coupling.** Sub-agents are one-shot. They don't maintain a conversation with the parent.

### Writing a sub-agent prompt

The parent's prompt to the sub-agent should look like a well-written task ticket, because that's exactly what it is. The sub-agent starts with no memory of the conversation, no knowledge of what has already been tried, and no implicit context. Everything it needs must be in the dispatch prompt.

Template:

```text
[Goal]
One or two sentences describing what you want the sub-agent to do.

[Context]
Why this task matters, what constraints apply, what's already been
tried or ruled out. The sub-agent doesn't know any of this otherwise.

[Instructions]
Specific steps, files to look at, tools to use. Or a question that
implies the steps.

[Output format]
What the sub-agent should return. Be specific — a structured summary
is more useful than "tell me what you found".

[Length budget]
"Report in under 300 words" or similar. Prevents bloated returns.
```

Bad dispatch: "look at the auth code and tell me if it's secure". The sub-agent has to guess what codebase, what definition of secure, what the report should look like.

Good dispatch: "Audit `src/auth/` for session-token handling vulnerabilities. Context: we're preparing for a SOC 2 review. Check for: tokens in logs, tokens in URLs, missing HttpOnly/Secure flags, predictable session IDs. Report a punch list of findings with file:line references, severity (low/med/high), and suggested fix. Under 400 words."

### What the parent does while the sub-agent runs

Two modes:

1. **Foreground** — parent waits for the sub-agent's result before continuing. Use when the parent genuinely needs the answer to proceed.
2. **Background** — parent dispatches and continues with other work. Use when tasks are independent and wall time matters.

Parallelism is the biggest wall-time win of the sub-agent pattern. Three independent tasks dispatched in parallel finish in roughly the time of the slowest one, not the sum.

### Specialized sub-agents

Some harnesses let you define reusable sub-agent *types* — prompts + tool permissions + behavior — that the parent can dispatch by name. Claude Code, for example, supports this via `.claude/agents/` files.

Typical specializations:

- **Explore** — fast codebase exploration, read-only, optimized for search.
- **Code reviewer** — audits a completed change against a plan and standards.
- **Plan writer** — turns a spec into an implementation plan.
- **Debugger** — focused on reproducing and isolating a failure.

Specializations matter because they codify workflow. Without them, every dispatch has to re-explain the role; with them, the parent just says "dispatch to reviewer" and the reviewer knows what that means.

> **Mid-level answer stops here.** A mid-level dev can describe what a sub-agent is. To sound senior, speak to dispatch discipline and the failure modes of delegation ↓
>
> **Senior signal:** the mistakes that turn sub-agents from a productivity win into a debugging nightmare.

### Delegation pitfalls

- **Over-delegation.** The parent dispatches even trivial work. Every dispatch has coordination overhead; sub-agents are not free. Dispatch when the isolation is worth the overhead.
- **Under-specified dispatches.** The sub-agent wastes effort trying to reconstruct context that the parent had. Either put it in the dispatch prompt or don't delegate.
- **Delegating understanding.** The anti-pattern "based on the sub-agent's findings, fix the bug" — the parent outsources the synthesis to the sub-agent and then blindly acts on the result. Synthesis is the parent's job; sub-agents gather and report, the parent decides.
- **Serial chains of trivial sub-agents.** Dispatching sub-agents in a chain where each one does very little is usually a sign that the task should have been one function call in the parent.
- **Stale context in specialized sub-agents.** A reusable "reviewer" prompt can drift from reality if the codebase's standards change. Version these like slash commands, review them, update them.
- **Lost audit trail.** Sub-agent conversations happen out of view. If you need the reasoning later for debugging or compliance, make sure the sub-agent's full trace is logged, not just its summary.

### The delegation contract, spelled out

The parent's job:

1. Decide *what* the sub-agent should do.
2. Write a self-contained dispatch prompt with goal, context, constraints, and output format.
3. Use the result as input to its own reasoning — never as a final answer by proxy.

The sub-agent's job:

1. Read the dispatch as the entire source of truth.
2. Do the work.
3. Report in the format requested, under the length budget.
4. Surface uncertainty honestly. "I couldn't find X" is more useful than inventing X.

### Closing

"So sub-agents are how you keep the parent's context clean while doing expensive or parallel work. They're not a general concurrency primitive; they're a context-isolation primitive. Dispatch deliberately, write the prompt as if the sub-agent is a stranger (because it is), parallelize when you can, and never delegate the synthesis step — that stays with the caller."
