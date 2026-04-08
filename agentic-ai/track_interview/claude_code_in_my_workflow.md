# Claude Code in my workflow

**Interview framing:**

"Claude Code is the coding assistant I reach for when I need real agentic behavior — not autocomplete, not chat, but something that can read my repo, run tests, edit files, and iterate on its own output. It lives in the terminal, which is the right home for it — I'm already in the terminal, and the tools it uses are the same tools I use. The interesting parts of Claude Code are the ones that make it *configurable*: hooks, slash commands, sub-agents, and MCP servers. Those are what turn it from a clever chatbot into something you can shape around a team's actual workflow."

### Why a CLI-first agent matters

- My editor is already opinionated, my terminal is where my real tools live (git, docker, test runners, CI scripts), and a CLI agent can use all of them without plugin-level integration.
- It's trivially scriptable — I can pipe things in, chain it with other commands, run it in CI, or wrap it in a pre-commit hook.
- It respects existing muscle memory: I don't change editors, I don't learn a new UI, I don't give up vim.

### The building blocks I actually use

- **Slash commands** — reusable prompts I've written for repeated tasks. Things like `/commit`, `/review-pr`, `/simplify`. Each is a markdown file with instructions; invoking the command loads that prompt into the session. Treat them as team-owned source code, not personal macros — they belong in the repo.
- **Hooks** — shell commands that run automatically on specific events (before a tool call, after a file edit, on session start). I use them for guardrails: a pre-edit hook that blocks edits to sensitive files, a post-edit hook that runs the linter. The key thing to understand is that *the harness runs hooks, not the model* — so they're trustworthy safety rails, not suggestions the model can ignore.
- **Sub-agents** — a way to fan work out to a separate context. When I need to explore a large codebase or run a long-running analysis, I dispatch a sub-agent so the noise doesn't pollute my main conversation. The main agent sees only the sub-agent's summarized report.
- **MCP servers** — external tool providers that expose capabilities to the agent via a standard protocol. I've used them to connect Claude Code to Supabase, Context7 (for library docs), and Linear. They turn the agent into something that can touch live systems, not just local files.
- **Memory files (CLAUDE.md)** — a persistent document loaded into every session that tells the agent about conventions, architecture, and do-not-touch rules for this specific project. This is how you make the agent actually useful across sessions without re-explaining the project every time.

### How I structure a real session

1. **Plan in dialogue** — I describe the task, let the model ask clarifying questions, and refuse to start implementing until I'm satisfied the plan is correct. This is the most underused feature of agentic tools; people skip straight to execution and then wonder why the output is wrong.
2. **Narrow the context** — I tell it exactly which files to look at. Letting it wander the repo burns tokens and drags in irrelevant context.
3. **Execute in small increments with checkpoints** — I use TDD where possible. The agent writes a failing test, I approve, it writes the implementation, runs the test, I review the diff.
4. **Keep a clean commit graph** — one logical change per commit, even when the agent produced it. Future-me needs to bisect, and a single 2000-line commit from an AI session is a nightmare.

> **Mid-level answer stops here.** A mid-level dev would list Claude Code features. To sound senior, speak to configuration strategy, safety rails, and team-level adoption ↓
>
> **Senior signal:** how you harden it, how you keep it safe for a team, and how you decide what to automate.

### Things that bite in production use

- **Runaway context windows.** Long sessions silently degrade as the model loses earlier constraints. I start a fresh session when a task is done rather than reusing a stale one.
- **Tool call loops.** Badly scoped tasks cause the agent to run the same read-file, run-test, edit-file cycle forever. I set explicit termination criteria in the prompt.
- **Silent destructive actions.** The agent can delete files, force-push, drop tables — anything it has permission to do. I use hooks and permission prompts to force human confirmation on anything irreversible. "Confirm before destructive action" is not a nice-to-have; it's a production requirement.
- **Secrets in context.** Pasting a `.env` file into the session leaks it to the model provider. I configure the project to ignore sensitive paths and I never paste credentials into the chat.
- **Team drift.** Different engineers with different settings produce wildly different output. Shared slash commands, shared `CLAUDE.md`, and shared hooks in the repo are how you make the tool team-owned instead of personally-tuned.

### What I automate vs what I keep manual

I automate things that are **objective, repeatable, and low-blast-radius**:
- Running linters and formatters after edits
- Generating commit messages from diffs
- Summarizing PRs
- Scaffolding test files

I keep **manual**:
- Merging to main
- Pushing to remotes
- Any database-touching script
- Anything that sends a message to another human

### Closing the answer

"So in practical terms, Claude Code is the agentic tool I've had the most hands-on time with — slash commands, hooks, sub-agents, and MCP servers are the primitives I use to shape it around my workflow. The philosophy I've landed on is: automate the mechanical, gate the irreversible, and keep the accountability loop short. Every file it edits, I read. Every commit it makes, I review. That's how I get the speedup without the liability."
