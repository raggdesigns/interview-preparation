# Self-critique loops

**Interview framing:**

"A self-critique loop is the pattern where the model produces an answer, then — in a second pass — reviews its own answer and produces a revised version. It's surprising how well this works on tasks where errors are obvious in hindsight but hard to avoid during generation. The reason it works is that generation and evaluation use different mental moves: one is optimizing for plausible output, the other is optimizing for correctness against a spec. Separating the two passes gives you a second chance with a different objective."

### The basic structure

```text
Task → [Generate] → Draft answer
                        ↓
                    [Critique] → Issues found
                        ↓
                    [Revise] → Improved answer
```

Each step is a separate LLM call. The critique step sees the draft and a critique-focused prompt ("find the three biggest problems with this answer"). The revise step sees the draft and the critique, and produces a new version.

The whole loop is one or two iterations in practice. More than three rarely helps and sometimes hurts, because later critiques start finding imaginary problems or converging on style instead of substance.

### Why it works

The model at temperature 0.7 producing a first draft is in "generation mode": it's emitting the most likely next token, and likely tokens are by definition the ones that sound plausible. Plausibility and correctness overlap but aren't the same thing. A generation-mode model will happily emit confident-sounding wrong answers because they are, locally, the most likely tokens.

Asked to critique — "identify three things wrong with this answer" — the same model shifts into an evaluation frame. It's no longer optimizing for plausibility; it's optimizing for finding flaws. The search space is different and it spots things the generation pass missed.

This is the same phenomenon humans experience when editing their own writing: you catch errors on the second read that you missed on the first, even though the same brain produced both passes.

### Where it helps

- **Code generation.** First draft compiles but has a bug; critique catches the bug; revise fixes it.
- **Factual writing.** First draft asserts something plausible; critique questions the assertion; revise either removes it or qualifies it.
- **Requirements adherence.** First draft addresses 7 of the 10 requirements; critique notices the missing 3; revise adds them.
- **Style and tone consistency.** First draft varies; critique normalizes; revise produces a uniform voice.
- **Math and step-by-step reasoning.** First draft has a subtle arithmetic error; critique, instructed to verify each step, catches it.

### Where it doesn't help (or actively hurts)

- **Tasks where the model has a shared blind spot.** If the generation and critique use the same model with the same training, they may agree on the wrong answer confidently. The critique "finds nothing wrong" and you ship.
- **Tasks where correctness is external.** The model can critique the style of code all day and never notice it doesn't compile against the real library version. Critique is no substitute for running the code.
- **Tasks where the first draft was already good.** You pay 2-3× the cost for a refinement that wasn't needed.
- **Creative tasks.** Self-critique tends to normalize and smooth creative output, losing the interesting parts.
- **Tasks too short to critique.** A one-sentence classification doesn't benefit.

### Variations

**Multi-model critique.** Generate with model A, critique with model B. Reduces the shared-blind-spot problem because the two models have different training and different biases. More expensive, more reliable.

**Adversarial critique.** Instead of "is this good?", instruct the critique step to "find three things wrong with this answer, assume it contains at least one factual error". The assumption biases the critique toward finding problems rather than confirming the draft.

**Structured critique.** Ask the critique to return a structured object with categories: `{factual_errors: [...], style_issues: [...], missing_requirements: [...]}`. Forces the critique to examine each category rather than producing a vague pass/fail.

**Critique-and-verify.** The critique step runs tools to verify claims — compiles code, runs tests, looks up facts — before emitting its critique. The critique is grounded in reality rather than in the model's own opinions.

**Majority voting across critiques.** Generate one draft, critique it N times with different random seeds, take the union of issues raised, revise once. Useful when you want high recall on problems.

### Practical implementation sketch

```python
def generate_with_critique(task):
    draft = llm(generate_prompt(task), temperature=0.7)

    critique = llm(critique_prompt(task, draft), temperature=0.3)
    # critique_prompt is adversarial: "find 3 problems, assume at least 1 exists"

    if critique.no_issues:
        return draft

    revised = llm(revise_prompt(task, draft, critique), temperature=0.3)
    return revised
```

The temperatures matter: generation at higher temp (some creativity), critique and revise at lower temp (stick to the evidence).

### Cost and latency

- You pay 2× tokens minimum (draft + critique) or 3× (draft + critique + revise).
- Latency is serial: each step waits on the previous. No wall-time win.
- Use self-critique when the cost of a wrong answer is much higher than 2-3× the cost of getting it right — high-stakes reasoning, code in critical paths, factual writing that will be published.

> **Mid-level answer stops here.** A mid-level dev can describe the pattern. To sound senior, speak to when it fails and how to know if it's helping ↓
>
> **Senior signal:** recognizing that self-critique can make things *worse* if you don't measure, and building it into a system with eval-based gates.

### The failure modes

- **Sycophantic critique.** The model is trained to be helpful and often praises the draft rather than finding real problems. Mitigation: adversarial prompting, explicit instruction to find N issues, structured critique categories.
- **Hallucinated problems.** The critique invents issues that aren't really there. Revising based on imaginary problems produces worse output than the original. Mitigation: require the critique to cite specific parts of the draft.
- **Style drift.** Each revision normalizes language, losing voice and specificity. After N iterations, output looks generic. Mitigation: cap iterations at 1-2 and measure quality, not just convergence.
- **Convergence on the wrong answer.** Both generation and critique use the same model's priors. They can agree on a confidently-wrong answer. Mitigation: multi-model critique, external verification (run the code, check the facts).
- **Cost blowup.** A critique loop in an agentic system can silently multiply request volume. Mitigation: only critique when the draft's risk justifies it; gate with a confidence check.

### How to know if self-critique is actually helping

Don't trust intuition. Measure it:

1. Build an eval set of tasks with known-good answers.
2. Run the pipeline with and without the critique loop.
3. Score both outputs against the eval.
4. Compare quality and cost. Accept the critique loop only if the quality lift justifies the cost.

It's common to find self-critique helps on some task categories and hurts on others. The right decision is often per-task-type, not global.

### A worked example in my head

"When I use self-critique for code generation, I do it like this: generate the implementation at temperature 0.5, then critique with the prompt 'Review this implementation for: (1) off-by-one errors, (2) unhandled error cases, (3) violations of the stated requirements'. The structured critique forces the model to check each category. If any issues are found, I revise. Then — and this is the important part — I run the tests. No matter how good the critique was, the final arbiter is the compiler and the test suite. The self-critique loop speeds up the iteration; it does not replace verification."

### Closing

"So self-critique is a high-leverage pattern for high-stakes tasks, a waste of money for low-stakes ones, and a silent quality-regression risk if you don't measure. Use it deliberately, not by default. Pair it with external verification whenever possible. And if generation and critique are the same model, be aware of the shared-blind-spot problem and consider multi-model critique when the stakes justify it."
