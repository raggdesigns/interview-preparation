# Testing agentic code

**Interview framing:**

"Testing agentic code is the problem of testing a system whose main component is nondeterministic, expensive, and slow. The temptation is to either not test it at all ('it's AI, it's unpredictable') or to test it with brittle string comparisons that break on every prompt tweak. Neither is right. The correct move is to test *behavior* — did the agent pick the right tools, in the right order, with the right arguments, producing the right effect — while mocking the things that make tests slow and flaky."

### What you're actually testing

A typical agentic system has these components:

1. **Prompt templates** — the instructions to the model.
2. **Tool definitions and implementations** — the hands.
3. **The agent loop** — the orchestration that runs the model, executes tools, feeds results back.
4. **The model itself** — not your problem to test, but your problem to constrain.

Each layer tests differently and each has different failure modes. Conflating them produces bad tests.

### Layer 1: Tool implementations — the easy part

Tools are just functions. Test them like any other function: unit tests, integration tests, boundary cases, error handling. This is normal software testing and nothing about the AI changes it.

```python
def test_get_user_returns_user_when_exists():
    user = get_user(user_id=42)
    assert user.id == 42
    assert user.email == "test@example.com"

def test_get_user_raises_on_invalid_id():
    with pytest.raises(InvalidUserIdError):
        get_user(user_id=-1)
```

If a tool has bugs, find them with tool-level tests. Don't find them through the agent.

### Layer 2: The agent loop — test with mocked tools

This is where it gets interesting. You want to test that the agent, given a prompt, picks the right tools and handles their results correctly. You don't want to hit real production systems every time.

The pattern: **mock the tools, not the model**. Let the real model run against fake tool implementations that record calls and return fixtures.

```python
def test_agent_looks_up_user_then_sends_email():
    mock_tools = MockToolSet({
        "get_user": lambda user_id: {"id": user_id, "email": "a@b.com"},
        "send_email": record_call,
    })

    result = run_agent(
        prompt="Send a welcome email to user 42",
        tools=mock_tools,
    )

    # Assertions on behavior, not on model text output.
    assert mock_tools.called("get_user", {"user_id": 42})
    assert mock_tools.called("send_email", contains={"to": "a@b.com"})
    assert mock_tools.call_order() == ["get_user", "send_email"]
```

**What you assert on:**

- **Which tools got called** — was the right action taken?
- **In what order** — was the sequencing right?
- **With what arguments** — did the model pass the correct data?
- **Did the loop terminate** — or did it get stuck?

**What you do NOT assert on:**

- The exact text of the model's response. It's nondeterministic. You'll chase the test forever.
- The exact wording of reasoning. Same reason.

### Layer 3: Prompt regression — test with a golden set

Prompt changes are code changes. They can silently break behavior. You need regression tests for prompts.

The mechanism: a **golden eval set** — a fixed list of input cases with expected *properties* of the output. Every prompt change runs against the set. If the metric regresses, the change doesn't ship.

```python
eval_set = load_eval_set("customer_classification_v1.json")

def test_classifier_meets_accuracy_threshold():
    correct = 0
    for case in eval_set:
        result = classify_ticket(case.input)
        if result.category == case.expected_category:
            correct += 1

    accuracy = correct / len(eval_set)
    assert accuracy >= 0.92  # baseline; updated when prompt changes
```

**Key discipline:**

- Assert on **properties**, not exact output. "Category is 'billing'" — not "first word is 'Based'".
- Use a **stable eval set** so runs are comparable over time.
- **Baseline the metric** on the current prompt and alert on regression.
- Run eval as part of CI for any PR touching prompts.

### Layer 4: End-to-end smoke tests

A small number of high-level tests that run the entire agent with real (or recorded) tool calls against a real model. Expensive, slow, flaky, but irreplaceable for catching integration issues.

Keep these:

- **Few in number** — tens, not hundreds.
- **Focused on happy path** — "user can do X end-to-end".
- **Tolerant of text variance** — assert on properties of the final state, not on phrasing.
- **Quarantine-able** — if they flake on a provider issue, you can isolate and skip without blocking deploys.

### Recording and replaying

A useful pattern for cheap, deterministic tests of the agent loop: **record** a real session with a real model, save the full request/response trace, and **replay** it in tests. The replayed session gives you deterministic behavior from the model without making real calls.

The tradeoff: replayed tests don't catch model-behavior changes. When the model is upgraded, your replayed tests still pass even if the real model would behave differently. Pair replayed tests with a smaller set of live tests that do hit the real model.

### Evaluating open-ended generation

For tasks with no single correct answer — summarization, writing, open-ended reasoning — you can't assert on exact output. Options:

- **LLM-as-judge.** A separate model call scores the output against a rubric. Cheap and scalable. Less reliable than humans but consistent enough to catch regressions.
- **Pairwise comparison.** Show the judge two outputs (baseline and new) and ask which is better. Easier than absolute scoring.
- **Reference-based metrics.** BLEU, ROUGE, BERTScore — automatic but blunt. Useful as trend indicators, not as truth.
- **Human eval on a sample.** Expensive, high signal. Reserve for major changes or sanity checks on the other methods.

### Testing structured output

When the agent returns JSON matching a schema, this is much easier: assert on the parsed object.

```python
def test_extraction_returns_valid_schema():
    result = extract_contact("Hi, I'm Jane at Acme, 555-1234")

    assert result.name == "Jane"
    assert result.company == "Acme"
    assert result.phone == "555-1234"
    assert result.email is None  # not present in input
```

Structured output is the single biggest ally of testable agentic code. When you can, design the system so the thing you care about comes out as structured data, not prose.

> **Mid-level answer stops here.** A mid-level dev can describe mocking and golden sets. To sound senior, speak to test discipline under nondeterminism and the systems-level concerns ↓
>
> **Senior signal:** the mindset that lets you ship agentic systems confidently without either naive trust or testing paralysis.

### Testing nondeterministic systems without losing your mind

- **Assert on invariants, not outputs.** "The answer contains a valid user ID" rather than "the answer equals X".
- **Use statistical assertions when necessary.** "95% of classifications are correct over 100 runs" is a fine test for a nondeterministic classifier.
- **Embrace flakiness budgets.** Accept that a few percent of runs may fail for non-bug reasons. Retry with backoff. Alert on sustained failure, not single failures.
- **Version your prompts and models.** A test that passed last week and fails today may be because the prompt changed, the model version changed, or a real bug. Versioning lets you distinguish.
- **Separate fast from slow tests.** Unit tests on tools run in CI on every PR. Eval-set tests run on prompt changes. End-to-end live tests run on a schedule, not on every commit.

### Common testing anti-patterns

- **Testing the mock.** Tests that only assert on the mock's behavior, proving nothing about the real tool. Always pair with integration tests at the tool level.
- **Golden set from production data without cleanup.** Production outputs include mistakes. Using them as "correct answers" teaches the test to expect mistakes.
- **Eval set that's too small.** 10 examples is not a regression suite. Expect 50-500 for meaningful signal.
- **Over-strict text assertions.** "The response contains 'Hello'" breaks when the prompt changes to "Hi". Test intent, not surface form.
- **No version control on prompts.** A prompt change is untested because the diff is invisible.
- **Cost-blind test runs.** Running the full eval set on every commit is expensive. Batch eval runs; don't run them on trivial changes.

### A mental model to leave with

"I treat the agent as three separable layers: the tools (normal code, normal tests), the agent loop (tests with mocked tools, asserting on behavior), and the prompts (eval sets with property-based assertions). I add a thin layer of end-to-end smoke tests over the whole thing. The prompt is source code, the eval set is my regression suite, and the acceptance bar is not 'passes' — it's 'meets or beats baseline on a fixed metric'."

### Closing

"So testing agentic code is testing at the right layers with the right tools. Unit-test deterministic components deterministically. Test the agent loop with mocked tools and behavior assertions. Test prompts with eval sets and property-based metrics. Keep a few end-to-end tests for integration. And accept that the output itself is nondeterministic — so your tests assert on what the system *did*, not on exactly what it *said*."
