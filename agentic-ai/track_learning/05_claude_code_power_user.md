# Claude Code as a power user

**Interview framing:**

"Claude Code is a CLI-first agentic coding tool. The model part is Claude; the interesting engineering is the *harness* around it — the part that runs tools, manages context, enforces safety rails, and shapes the workflow. Becoming a power user means understanding that harness as a configurable system, not a black box."

> See also the interview-track companion: [claude_code_in_my_workflow.md](../track_interview/claude_code_in_my_workflow.md). This file is the mechanical "how to actually configure it" view.

### The mental model

A Claude Code session is a loop: the model reads the conversation + current context, decides to either (a) emit a user-facing message, or (b) call a tool. The harness runs the tool, feeds the result back, and loops. Everything you configure is some knob on that loop.

The major knobs are: **tools**, **context**, **commands**, **hooks**, **subagents**, and **memory**.

### Tools — what the agent can touch

Built-in tools (Read, Edit, Write, Bash, Grep, Glob, etc.) are the primitives. The agent can chain them arbitrarily. Custom tools come from **MCP servers** — external processes that speak the Model Context Protocol and expose additional tools.

Permissions control what runs without asking. Three modes, roughly: deny-all, ask-every-time, auto-allow safe operations. Pick based on the blast radius of the session.

### Context — what the agent sees

Claude Code builds context from several sources on every turn:

- **The current conversation** — user messages, model responses, tool results.
- **`CLAUDE.md`** — a markdown file loaded at session start. Project-level instructions, conventions, do-not-touch rules. Lives at the repo root (or in `~/.claude/` for global). This is the single most important configuration for real project work.
- **System prompt additions** — short directives set in settings.
- **File reads the agent has already done** — stay in context until pushed out.

**Practical tip:** `CLAUDE.md` is loaded into every session. Keep it tight. Everything in it costs tokens per turn. Big architectural docs belong in linked files the agent reads on demand, not in CLAUDE.md itself.

### Slash commands — reusable prompts

Slash commands are markdown files that act as reusable prompts. Writing `/commit` in the session expands to the contents of `.claude/commands/commit.md` (or the user-level equivalent). The command can contain arguments, instructions, and references to other files.

I use slash commands for:

- `/commit` — the repo's commit conventions and checks
- `/review-pr` — a structured PR review prompt
- `/simplify` — a code-simplification workflow
- `/test` — project-specific test-running and interpretation steps

Shared slash commands live in the repo (`.claude/commands/`), personal ones live in `~/.claude/commands/`. Team-owned commands belong in the repo; personal shortcuts don't.

### Hooks — safety rails the model can't bypass

Hooks are shell commands that the harness runs automatically on events:

- `PreToolUse` — before a specific tool runs
- `PostToolUse` — after a tool runs
- `SessionStart` — when a session begins
- `UserPromptSubmit` — when the user sends a message
- `Stop` — when the session ends

The crucial property: **hooks run in the harness, not the model**. The model can't skip them, talk them out of running, or be prompt-injected into disabling them. That makes hooks the right place for hard invariants.

Canonical uses:

- Block edits to sensitive files (`.env`, secrets, production configs)
- Run linters and formatters after every edit
- Reject bash commands matching dangerous patterns
- Log tool calls to an audit file
- Show a contextual reminder at session start

Configuration lives in `settings.json` under `hooks`. A hook can exit non-zero to block the action, or return structured output to inject feedback.

### Subagents — scoped sub-sessions

A subagent is a separate session spawned from the main one with its own context window. The main session dispatches work ("explore the codebase and find all call sites of function X"), the subagent runs, and only its *final summary* returns to the main session.

Why this matters: exploration burns tokens. A codebase search that reads 40 files and reasons over all of them would balloon the main conversation; dispatching it to a subagent keeps the main context clean. The main session sees a 200-token summary instead of 40 file reads.

I use subagents for:

- **Exploration** — "find everything related to X"
- **Parallel independent work** — multiple unrelated changes
- **Heavy research** — reading long docs or many files
- **Code review of a completed chunk** — the reviewer subagent has fresh eyes, uncontaminated by implementation context

Specialized subagents live in `.claude/agents/` as markdown files describing the subagent's role and tools.

### Memory — persistence across sessions

Two layers:

1. **`CLAUDE.md`** — the durable "this is what you need to know about this project" document. Loaded every session.
2. **Memory files** (tool-managed) — notes the agent can write and read across sessions. Useful for recording decisions, gotchas, and work-in-progress state.

The key discipline: memory is not a free-for-all notepad. Write things worth remembering, update things that change, delete things that become wrong. Stale memory is worse than no memory.

### Settings — where everything lives

- `~/.claude/settings.json` — user-level (applies to all projects)
- `<repo>/.claude/settings.json` — project-level (committed to the repo, shared with the team)
- `<repo>/.claude/settings.local.json` — project-level personal overrides (gitignored)

Layering lets you share team standards in the repo while keeping personal preferences out.

### A power-user session anatomy

1. **Session start** — `CLAUDE.md` loaded, session-start hooks run (e.g. show current git status, load memory).
2. **Plan dialogue** — I describe the task, model asks clarifying questions, we align before writing any code.
3. **Narrowed execution** — I point the agent at specific files. No wandering.
4. **Checkpointed edits** — small diffs, test after each, commit in logical chunks.
5. **Destructive actions** — always confirmed, often blocked behind hooks.
6. **Session end** — memory updated if anything worth remembering came out of the session.

### The power-user mistakes I see others make

- **Treating `CLAUDE.md` as a brain dump.** Every token costs per turn. Keep it tight.
- **Reinventing guardrails in the prompt.** If the rule is "never touch `.env`", that's a hook, not a prompt instruction. Prompts can be injected around; hooks can't.
- **Single-session marathons.** Long sessions degrade as context fills. Start fresh sessions for new tasks.
- **Personal settings where team settings belong.** If a slash command or hook is useful, commit it to the repo. Shared tooling compounds.
- **Skipping the plan step.** The best feature of agentic tools is plan-before-execute. People skip it to save time, then spend 5x as long debugging output.

### Closing

"So the power-user move is treating Claude Code as a configurable system: tools, context, commands, hooks, subagents, memory, settings. Each is a knob; each has a right place. Shared knobs live in the repo, personal ones live in your home directory, and hard safety rails live in hooks — not in prompts the model can be talked out of."
