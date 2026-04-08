# How I use AI in daily work

**Interview framing (how I'd open):**

"AI coding assistants have shifted from autocomplete to genuine collaborators in the last two years. I use them every day, but I use them *deliberately* — they're fantastic at some things and dangerous at others, and knowing the difference is where the real productivity comes from. I treat them as a very fast, very eager junior engineer who never gets tired but also never feels accountable, so the accountability has to stay with me."

### What I actually use them for

- **Exploration and orientation in unfamiliar code** — "walk me through how requests flow through this middleware stack" is a question a senior colleague would answer in five minutes; an AI assistant does it in ten seconds with file citations.
- **Boilerplate and scaffolding** — CRUD endpoints, DTO classes, test fixtures, migration files. The kind of code where the *design* is in my head and the typing is the bottleneck.
- **Rubber-ducking and second opinions** — I describe a design problem, ask for trade-offs, then argue with the answer. Even when the AI is wrong, the act of refuting it sharpens my own thinking.
- **Test generation** — especially negative tests and edge cases I'd miss under pressure. I still write the happy path myself because that's where the intent lives.
- **Refactoring mechanical changes across large codebases** — renames, signature changes, migrating away from deprecated APIs. Much faster than grep-and-replace, much safer than codemods for mid-complexity changes.
- **Writing the things I hate writing** — commit messages, PR descriptions, release notes, docstrings. Content I'd write anyway, just faster.

### What I deliberately don't use them for

- **Security-critical code paths.** Auth, crypto, session handling, SQL that touches untrusted input. I write those by hand and the AI reviews — never the other way around.
- **Business logic I don't fully understand yet.** If I can't specify the behavior precisely, I shouldn't be delegating the implementation. I'll end up with plausible-looking code that's subtly wrong, and the debugging cost will dwarf the savings.
- **Anything where "almost right" is worse than "nothing at all"** — migrations, financial calculations, data transformations on production data.

### The workflow

A typical session looks like this:

1. I start with a **plan** — either in my head or written out. The AI does not write the plan; I do. If I can't write the plan, I don't know the problem well enough.
2. I give the AI **narrow, well-scoped tasks** from that plan. "Implement this function with these inputs and these outputs" — not "build the feature".
3. I **read every line** before accepting. Not skim — read. This is the discipline that separates working with AI from being *used* by AI.
4. I **run the tests** I wrote (or asked the AI to write and then audited). Green tests are a signal, not proof.
5. I **commit in small, legible chunks** so that if something is wrong I can bisect. AI-generated code amplifies the cost of large commits.

> **Mid-level answer stops here.** A mid-level dev would describe *which tools they use* and *what they generate*. To sound senior, you also need to speak to the next section ↓
>
> **Senior signal:** the judgment calls, the anti-patterns you've learned to avoid, and the accountability model.

### The failure modes I've learned to watch for

- **Plausible hallucinations in the library surface area.** The AI will invent a method that looks exactly like something the library *would* have but doesn't. Always check against the actual docs for anything non-trivial — I use Context7 or the real docs, not the model's memory.
- **Confidence-weighted error.** The AI's confidence is not correlated with correctness. A wrong answer delivered in authoritative prose is *more* dangerous than an uncertain one, because it bypasses your skepticism.
- **Context collapse.** In a long session the model forgets constraints you set twenty messages ago. I re-state critical constraints when I move to a new subtask.
- **Over-eager scope expansion.** The AI will helpfully "improve" adjacent code you didn't ask it to touch. I reject those changes as a matter of policy — scope discipline is a senior trait and the AI has none of it.
- **Tests that test the mock, not the code.** Generated tests love to assert on fixtures. I audit test meaningfulness, not just coverage.

### The accountability principle

The code I ship is *my* code regardless of how it was produced. If it breaks in production at 3 a.m., "the AI wrote it" is not an answer I can give — and if I wouldn't give that answer, I have no business accepting code I don't understand. This is the single mental model that keeps AI collaboration productive: I am the senior engineer, the AI is the junior, and the review standard doesn't change because the author is non-human.

### Closing the answer

"So in practice, AI has made me roughly two to three times faster on the mechanical parts of the job — scaffolding, refactoring, exploration, docs. It hasn't made me faster on the hard parts — design, debugging novel problems, reasoning about distributed systems failure modes — because those are bottlenecked on my thinking, not my typing. The productivity gain is real, but it compounds with discipline and collapses without it."
