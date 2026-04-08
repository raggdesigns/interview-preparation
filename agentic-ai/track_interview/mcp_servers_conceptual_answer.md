# MCP servers — conceptual answer

**Interview framing (honest version — what you can truthfully say today):**

"MCP — the Model Context Protocol — is a standard way for an AI agent to discover and call external tools and data sources. The problem it solves is simple: before MCP, every agent had its own ad-hoc way to plug in tools, so integrations didn't compose and everyone reinvented the same wiring. MCP turns tool-providing into a protocol, the same way LSP did for language servers and editors. I've used MCP servers as a *consumer* — connecting Claude Code to Supabase, to Context7 for live library docs, and to project-management tools — but I haven't yet shipped one I built myself. What I do have is a solid conceptual grasp of the protocol, which I can walk through."

### The shape of the protocol

MCP is a client–server protocol. The agent (Claude Code, a custom app using the Claude SDK, etc.) is the **client**. A tool provider is the **server**. They speak JSON-RPC over a transport — typically stdio for local servers, HTTP/SSE for remote ones.

An MCP server exposes three kinds of things:

- **Tools** — functions the agent can call, with a JSON-schema-defined input. "Create a Linear issue", "run this SQL query", "fetch this file".
- **Resources** — readable data the agent can pull into context. "Here's the latest schema", "here's today's logs".
- **Prompts** — reusable prompt templates the server can offer to the client.

### The lifecycle

1. Client connects to server (spawns it as a subprocess for stdio transport, or opens HTTP for remote).
2. Client asks: "what tools do you have?" Server returns a list of tool definitions with JSON schemas.
3. The agent now sees those tools as if they were native. When it decides to call one, the client forwards the call to the server, the server executes it, returns a result, and the client hands the result back to the model.
4. Same pattern for resources and prompts.

The elegant part is that the *agent doesn't know or care* whether a tool is built-in or served by MCP. The protocol hides the integration.

### Why this matters for backend engineers

- **It's the production integration story for agents.** If you want an LLM-powered system to touch your database, your ticketing system, your monitoring stack, MCP is the straight path. You don't glue tools into each agent framework separately.
- **It enforces a clean contract** — tool definitions are JSON schemas, which means the inputs are validated, the outputs are structured, and there's no hand-crafted prompt coupling.
- **It's local-first by default.** An MCP server running on stdio has zero network surface and zero auth story to invent. That makes it a safe way to expose sensitive tools without building an API gateway.

> **Mid-level answer stops here.** A mid-level dev would describe "it's a protocol for tools". To sound senior, speak to security, failure modes, and design trade-offs ↓
>
> **Senior signal:** the boundaries and pitfalls you'd think about before letting an MCP server touch production.

### Things I'd think about before letting one touch production

- **Authorization is your problem, not the protocol's.** MCP gives you a tool-calling transport; it doesn't give you "this user can do this thing". If your server wraps a database, it needs its own authz model. "The agent called this tool" is not the same as "the user authorized this action".
- **Tools should be narrow, not god-like.** A tool called `run_sql` is an incident waiting to happen. A tool called `get_user_by_id` is not. Shape the surface area of the server the same way you'd shape an internal API: principle of least privilege.
- **Determinism and idempotency.** If the agent retries, the tool had better be idempotent — or the agent had better be told it can't retry. Write-side tools need an explicit idempotency key or they'll produce duplicates when the agent loops.
- **Tool description is the contract.** The model decides whether to call a tool based on the natural-language description in the schema. A vague description produces unreliable calling. A precise description with examples produces reliable calling. Spend real effort on the description — it's not metadata, it's part of the API.
- **Logging and audit.** Every tool call needs a structured log entry: who, what, when, with what arguments, with what result. When something goes wrong, "the agent did it" is not an audit trail.
- **Schema-validated outputs.** The server should return structured data matching a documented shape, not free-form strings. The agent will interpret whatever you give it; structured responses cut hallucination-on-parsing dramatically.

### If I were building one from scratch

"I'd start with a stdio server in TypeScript or Python using the official SDK, expose one narrow tool, write the tool description carefully, and test it against Claude Code locally. Once that's solid, I'd add more tools, then consider whether any of them need to become a remote HTTP server — which only makes sense when multiple clients or non-local agents need them. The tempting mistake is to build a big server up front; the right move is to start with one tool and grow."

### Closing the answer

"So I've used MCP servers as a consumer enough to know how the protocol shapes real workflows — what makes a good tool definition, where the security boundaries sit, and why narrow is better than flexible. Building one is on my near-term list, and when I do I already know the trade-offs I want to make: narrow tools, clear schemas, explicit auth, structured outputs, and aggressive logging. The protocol is simple; the discipline around it is what separates a useful integration from a liability."
