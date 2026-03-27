# Serbian Translation Design

## Overview

Add Serbian (Latin script) translations to the interview preparations repository using side-by-side `.sr.md` files. Both language versions coexist on the same branch, with automated validation to keep them in sync.

## Goals

- Prepare for interviews in both English and Serbian depending on context
- Keep translations discoverable and in sync with English originals
- Make it easy for friends, colleagues, and contributors to add/update translations
- Automate sync validation so nothing falls through the cracks

## File Structure

Every translatable `.md` file gets a `.sr.md` counterpart in the same directory:

```
architecture/
├── questions.md
├── questions.sr.md
├── cqrs.md
├── cqrs.sr.md
├── event_sourcing.md
└── event_sourcing.sr.md
```

This applies to all organizational patterns in the repo:
- Root-level topic files (e.g., `php/generators.md` -> `php/generators.sr.md`)
- Files in `answers/` subfolders (e.g., `microservices/answers/saga_pattern.md` -> `microservices/answers/saga_pattern.sr.md`)
- Files in nested subfolders (e.g., `oop/design_patterns/singleton.md` -> `oop/design_patterns/singleton.sr.md`)

## Translation Scope

### Translated

- All topic/answer files: explanatory text translated, code blocks kept in English
- `questions.md` index files -> `questions.sr.md` (with links updated to point to `.sr.md` files)
- `README.md` -> `README.sr.md`
- `TOPIC_TEMPLATE.md` -> `TOPIC_TEMPLATE.sr.md`

### NOT Translated

- `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `LICENSE` (standard open-source, stay English)
- `.github/` templates (GitHub UI is English)
- Code blocks, variable names, technical terms without natural Serbian equivalents

## Translation Rules

- **Script:** Serbian Latin (Latinica) only. Never Cyrillic.
- **Code blocks:** Keep entirely in English (including comments and variable names)
- **Technical terms:** Use the Serbian term where a natural equivalent exists. Keep English for terms that are universally used in Serbian dev communities (e.g., "dependency injection", "singleton", "factory").
- **Internal links:** Serbian files link to other Serbian files:
  ```markdown
  > Pogledajte takođe: [Event Sourcing](event_sourcing.sr.md)
  ```
- **File template:** Same structure as the English `TOPIC_TEMPLATE.md`, with section headers translated.

## Sync Validation

### Pre-commit Hook

A shell script configured in `.claude/settings.json` that runs on every commit. It performs three checks:

1. **Missing translations:** New `.md` file added without a corresponding `.sr.md` -> warning
2. **Stale translations:** Existing `.md` file modified but corresponding `.sr.md` not modified in the same commit -> warning
3. **Orphaned translations:** `.md` file deleted but corresponding `.sr.md` still exists -> warning

The hook **warns but does not block commits**. Rationale:
- Sometimes you work on English first and translate later
- Forcing translation in every commit would slow down content development
- Warnings provide visibility without friction

Example output:
```
[translation-sync] WARNING: Modified architecture/cqrs.md — check if architecture/cqrs.sr.md needs updating
[translation-sync] WARNING: New file testing/load_testing.md — no Serbian translation found (testing/load_testing.sr.md)
```

Files excluded from hook checks:
- `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `LICENSE`
- `.github/**`
- `package.json`, config files

### Coverage Report Script

A standalone script at `scripts/translation-coverage.sh` that can be run on demand to show:

- Total English files vs. translated files (count and percentage)
- List of missing translations
- List of potentially stale translations (English file newer than Serbian counterpart)
- Per-domain breakdown

Example output:
```
Translation Coverage Report
===========================
Overall: 45/202 files translated (22%)

By domain:
  general:       8/20  (40%)
  oop:           12/36 (33%)
  php:           10/34 (29%)
  architecture:  5/6   (83%)
  ...

Missing translations (157):
  caching/cache_invalidation.md
  caching/redis_vs_memcached.md
  ...

Potentially stale (3):
  architecture/cqrs.sr.md (English modified 2026-03-25, Serbian modified 2026-03-10)
  ...
```

## Branch Strategy

### Initial Translation Phase

- Work on a feature branch: `feature/serbian-translation`
- Translate in batches by domain
- Merge to `main` via PR after each batch or after all domains are complete

### Ongoing Workflow

- All content (English + Serbian) lives on `main`
- New topics: create both `.md` and `.sr.md` (hook reminds if forgotten)
- Updated topics: hook warns to check Serbian version

## Translation Order

Priority based on file count and interview relevance:

1. **Root docs:** `README.md`, `TOPIC_TEMPLATE.md`
2. **Index files:** All 13 `questions.md` files (enables Serbian navigation immediately)
3. **Topic files by domain:**
   - `general` (20 files) — foundational interview topics
   - `oop` (36 files) — core OOP concepts and design patterns
   - `php` (34 files) — language-specific knowledge
   - `architecture` (6 files) — system design
   - `microservices` (22 files) — distributed systems
   - `solid` (6 files) — design principles
   - `testing` (13 files) — testing practices
   - `highload` (12 files) — scalability
   - `ddd` (9 files) — domain-driven design
   - `mysql` (7 files) — database concepts
   - `symfony` (15 files) — framework-specific
   - `caching` (5 files) — caching strategies
   - `javascript` (3 files) — JS fundamentals

Total: ~202 files to translate.

## Implementation Notes

- Translation will be batched across multiple Claude Code sessions using parallel agents per domain
- Each agent translates one domain at a time to avoid conflicts
- The hook and coverage script are implemented first, before any translation begins
- CI/CD: existing markdown linting and link checking should be extended to cover `.sr.md` files (markdownlint already picks up all `.md` files by glob; link checker needs to validate `.sr.md` internal links)
