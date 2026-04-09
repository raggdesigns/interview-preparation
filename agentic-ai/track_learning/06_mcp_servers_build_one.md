# MCP servers — build one

**Interview framing:**

"The fastest way to actually understand MCP is to build the smallest possible server and connect it to a real client. The protocol is simple once you've seen it work end-to-end: JSON-RPC over stdio, a handshake, a tool registration, and a request/response loop. Everything beyond that is incremental."

> See also the interview-track companion: [mcp_servers_conceptual_answer.md](../track_interview/mcp_servers_conceptual_answer.md). This file is the hands-on build-it-yourself curriculum.

### What you're building

A minimal MCP server that exposes one tool — let's say `get_current_weather` — and returns a structured result. Once that works against Claude Code, every other feature (more tools, resources, prompts, HTTP transport) is an incremental extension of the same pattern.

### Prerequisites

- An official SDK: `@modelcontextprotocol/sdk` for TypeScript, `mcp` for Python.
- An MCP-capable client. Claude Code is the simplest to test against.
- A terminal where you can run the server as a subprocess.

### The minimum viable server (TypeScript)

```typescript
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

const server = new Server(
  { name: "weather-mcp", version: "0.1.0" },
  { capabilities: { tools: {} } }
);

// Tell the client what tools we expose.
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "get_current_weather",
      description:
        "Returns the current weather for a city. Use when the user asks about weather, temperature, or conditions in a specific location.",
      inputSchema: {
        type: "object",
        properties: {
          city: {
            type: "string",
            description: "City name, e.g. 'Belgrade' or 'New York'",
          },
          unit: {
            type: "string",
            enum: ["celsius", "fahrenheit"],
            description: "Temperature unit. Defaults to celsius.",
          },
        },
        required: ["city"],
      },
    },
  ],
}));

// Handle a tool call.
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  if (request.params.name !== "get_current_weather") {
    throw new Error(`Unknown tool: ${request.params.name}`);
  }

  const { city, unit = "celsius" } = request.params.arguments as {
    city: string;
    unit?: "celsius" | "fahrenheit";
  };

  // In a real server this would call a weather API. For now we fake it.
  const tempC = 22;
  const temp = unit === "fahrenheit" ? Math.round(tempC * 1.8 + 32) : tempC;

  return {
    content: [
      {
        type: "text",
        text: JSON.stringify({
          city,
          temperature: temp,
          unit,
          conditions: "sunny",
        }),
      },
    ],
  };
});

const transport = new StdioServerTransport();
await server.connect(transport);
```

That's the whole server. ~50 lines to expose one tool.

### Connecting it to Claude Code

Add it to your Claude Code MCP configuration (`~/.claude/settings.json` or project-level):

```json
{
  "mcpServers": {
    "weather": {
      "command": "node",
      "args": ["/absolute/path/to/weather-mcp/dist/index.js"]
    }
  }
}
```

Restart the session. The agent now has a `get_current_weather` tool available alongside the built-in ones. Ask it "what's the weather in Belgrade?" and watch the tool call happen.

### The protocol underneath

MCP uses JSON-RPC 2.0 over a transport (stdio for local servers, HTTP+SSE for remote). The handshake:

1. Client spawns the server process and connects to its stdin/stdout.
2. Client sends `initialize` with its capabilities. Server replies with its capabilities.
3. Client sends `notifications/initialized`.
4. Client may now call `tools/list`, `tools/call`, `resources/list`, `resources/read`, `prompts/list`, `prompts/get`.

Everything is framed as JSON-RPC messages. You can see them if you log stdin/stdout during development — which I recommend doing the first few times, because seeing the actual wire protocol removes all mystery.

### Adding resources

Resources are *read-only* data the agent can pull into context. Tools *do* things; resources *are* things. Example: expose the current schema of a database as a resource.

```typescript
server.setRequestHandler(ListResourcesRequestSchema, async () => ({
  resources: [
    {
      uri: "weather://supported-cities",
      name: "Supported cities",
      description: "List of cities this server can provide weather for.",
      mimeType: "application/json",
    },
  ],
}));

server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
  if (request.params.uri === "weather://supported-cities") {
    return {
      contents: [
        {
          uri: request.params.uri,
          mimeType: "application/json",
          text: JSON.stringify(["Belgrade", "New York", "Tokyo"]),
        },
      ],
    };
  }
  throw new Error("Unknown resource");
});
```

The agent can now list resources and read the one it cares about.

### Adding prompts

Prompts are reusable prompt templates the server ships. The client lists them, picks one, and uses it as a starting message. Useful when the server wants to provide a canned workflow: "write a weather report for <city>".

### When to use stdio vs HTTP

- **stdio** — local tools, zero network surface, zero auth. The default for dev tools, IDE integrations, and any per-user process. This is what you build first.
- **HTTP + SSE** — remote services, multiple clients, shared infrastructure. You need this when an MCP server hosts something that isn't tied to one user's machine — e.g. a team's shared observability stack, a hosted knowledge base.

Don't start with HTTP. Start with stdio, make it work, then migrate if you need to.

### Things you should do before letting any MCP server touch production

- **Scope tools narrowly.** `run_sql` is a footgun; `get_user_by_id`, `list_orders`, `search_products` are not.
- **Authorize explicitly.** The MCP transport gives you no auth. If your server wraps sensitive data, it needs its own authorization layer — RBAC, per-tool permissions, audit log.
- **Return structured output.** Every tool response should be a JSON object with named fields. The agent will misread prose; it will parse structure reliably.
- **Idempotency for writes.** Give write tools an idempotency key or make them naturally idempotent.
- **Bounded output.** Never return unbounded data. Always paginate, cap, or summarize.
- **Structured logging.** Every tool call goes to an audit log with request, response, timing, and caller identity.
- **Graceful errors.** Return a structured error object with a human-readable message; never let the process crash mid-call.

### Testing your MCP server

- **Unit-test the handlers** directly, without the transport. They're just functions taking a request and returning a response.
- **Integration-test the protocol** — spawn the server and speak JSON-RPC to it from a test harness. The SDK provides helpers.
- **Contract-test the tool schema** — validate that your tool descriptions actually produce the output shape you documented. Run a small set of real LLM calls against the server and assert on the tool-call arguments.
- **End-to-end test** by running against Claude Code itself in a scripted flow.

### The natural progression

1. One tool, stdio, returns fake data.
2. One tool, real data source.
3. Multiple narrow tools, all read-only.
4. Add a write tool with idempotency.
5. Add resources.
6. Add structured logging and error handling.
7. Migrate to HTTP if you need remote access, add auth at that boundary.
8. Publish the server as a package or internal service.

Each step is incremental and the mental model stays the same the whole way.

### Closing

"So the build-one exercise is small, and that's the point. The protocol is simple, the SDK is thin, and the real engineering is the same engineering you'd apply to any internal API: narrow tools, explicit auth, structured output, idempotent writes, audit logs. Build the smallest possible server, wire it to Claude Code, watch the JSON-RPC fly, then grow it deliberately."
