# Contributing

Thanks for your interest in contributing to this repository.

## Scope

This project currently accepts **content-only contributions**:

- New interview topics
- Corrections and clarifications
- Improved examples and explanations
- Filling missing answers referenced from `questions.md`

Out of scope for now:

- Large folder reorganizations
- Tooling overhauls unrelated to content
- Unrelated refactors

## How to contribute

1. Fork the repository
2. Create a branch from `main`
3. Add or update content
4. Ensure links are valid and markdown lint passes
5. Open a pull request

## Content rules

- Use [TOPIC_TEMPLATE.md](TOPIC_TEMPLATE.md) for new topic files
- Prefer clear, interview-focused explanations
- Add practical examples (PHP examples when relevant)
- Keep terminology consistent with existing files
- Link new topic files from the relevant `questions.md`

## File naming

Use `snake_case.md` names.

## Commit message examples

- `Add: message_queue_vs_event_bus`
- `Fix: cqrs examples`
- `Improve: redis_basics`

## Pull request checklist

- Change is focused and minimal
- New file follows the topic template
- `questions.md` links are updated when needed
- No unrelated file changes
