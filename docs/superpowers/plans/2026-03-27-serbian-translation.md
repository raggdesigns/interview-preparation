# Serbian Translation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Serbian (Latin script) side-by-side `.sr.md` translations to the interview preparations repo, with automated sync validation tooling.

**Architecture:** Every English `.md` file gets a `.sr.md` counterpart in the same directory. A pre-commit hook warns about sync issues. A coverage script reports translation status. Translation is text-only — code blocks stay in English.

**Tech Stack:** Shell scripts (bash), Claude Code hooks (`.claude/settings.json`), markdown

**Spec:** `docs/superpowers/specs/2026-03-27-serbian-translation-design.md`

---

## Phase 1: Tooling (Tasks 1-3)

Build the sync validation infrastructure before any translation begins.

### Task 1: Create the pre-commit sync hook script

**Files:**
- Create: `scripts/translation-sync-hook.sh`

- [ ] **Step 1: Create the hook script**

```bash
#!/usr/bin/env bash
# translation-sync-hook.sh — Warns about translation sync issues on commit.
# Non-blocking: prints warnings but always exits 0.

set -euo pipefail

# Excluded paths (not translatable)
EXCLUDED="^(CONTRIBUTING\.md|CODE_OF_CONDUCT\.md|LICENSE|\.github/|docs/|node_modules/|\.claude/)"

# Get staged .md files (added, modified, deleted)
ADDED_OR_MODIFIED=$(git diff --cached --name-only --diff-filter=AM -- '*.md' | grep -v '\.sr\.md$' | grep -Ev "$EXCLUDED" || true)
DELETED=$(git diff --cached --name-only --diff-filter=D -- '*.md' | grep -v '\.sr\.md$' | grep -Ev "$EXCLUDED" || true)
ALL_STAGED_SR=$(git diff --cached --name-only -- '*.sr.md' || true)

found_issues=false

# Check 1: New or modified English files — is the .sr.md also staged?
while IFS= read -r file; do
  [ -z "$file" ] && continue
  sr_file="${file%.md}.sr.md"
  if ! echo "$ALL_STAGED_SR" | grep -qx "$sr_file"; then
    if [ ! -f "$sr_file" ]; then
      echo "[translation-sync] WARNING: New file $file — no Serbian translation found ($sr_file)"
    else
      echo "[translation-sync] WARNING: Modified $file — check if $sr_file needs updating"
    fi
    found_issues=true
  fi
done <<< "$ADDED_OR_MODIFIED"

# Check 2: Deleted English files — does the .sr.md still exist?
while IFS= read -r file; do
  [ -z "$file" ] && continue
  sr_file="${file%.md}.sr.md"
  if [ -f "$sr_file" ] && ! echo "$ALL_STAGED_SR" | grep -qx "$sr_file"; then
    echo "[translation-sync] WARNING: Deleted $file — orphaned translation still exists ($sr_file)"
    found_issues=true
  fi
done <<< "$DELETED"

if [ "$found_issues" = true ]; then
  echo "[translation-sync] Run 'bash scripts/translation-coverage.sh' for full translation status."
fi

exit 0
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x scripts/translation-sync-hook.sh`

- [ ] **Step 3: Test the hook manually**

Run: `bash scripts/translation-sync-hook.sh`
Expected: No warnings (nothing is staged). Exits 0.

- [ ] **Step 4: Commit**

```bash
git add scripts/translation-sync-hook.sh
git commit -m "feat: add translation sync pre-commit hook script"
```

### Task 2: Configure the hook in Claude Code settings

**Files:**
- Modify: `.claude/settings.local.json`

- [ ] **Step 1: Add the pre-commit hook configuration**

Update `.claude/settings.local.json` to include the hook. The file currently contains:
```json
{
  "permissions": {
    "allow": [
      "Bash(claude mcp:*)"
    ]
  }
}
```

Replace with:
```json
{
  "permissions": {
    "allow": [
      "Bash(claude mcp:*)"
    ]
  },
  "hooks": {
    "PreCommit": [
      {
        "command": "bash scripts/translation-sync-hook.sh",
        "description": "Check translation sync status"
      }
    ]
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add .claude/settings.local.json
git commit -m "feat: configure translation sync hook in Claude settings"
```

### Task 3: Create the coverage report script

**Files:**
- Create: `scripts/translation-coverage.sh`

- [ ] **Step 1: Create the coverage script**

```bash
#!/usr/bin/env bash
# translation-coverage.sh — Reports translation coverage across all domains.

set -euo pipefail

# Translatable domains
DOMAINS=(architecture caching ddd general highload javascript microservices mysql oop php solid symfony testing)

# Excluded files (not translatable)
EXCLUDED_FILES=("CONTRIBUTING.md" "CODE_OF_CONDUCT.md" "LICENSE")

total_en=0
total_sr=0
missing_files=()
stale_files=()

echo ""
echo "Translation Coverage Report"
echo "==========================="
echo ""

# Root docs
for root_file in README.md TOPIC_TEMPLATE.md; do
  if [ -f "$root_file" ]; then
    total_en=$((total_en + 1))
    sr_file="${root_file%.md}.sr.md"
    if [ -f "$sr_file" ]; then
      total_sr=$((total_sr + 1))
      # Check staleness via git log
      en_ts=$(git log -1 --format=%ct -- "$root_file" 2>/dev/null || echo 0)
      sr_ts=$(git log -1 --format=%ct -- "$sr_file" 2>/dev/null || echo 0)
      if [ "$en_ts" -gt "$sr_ts" ] 2>/dev/null; then
        en_date=$(git log -1 --format=%ci -- "$root_file" 2>/dev/null | cut -d' ' -f1)
        sr_date=$(git log -1 --format=%ci -- "$sr_file" 2>/dev/null | cut -d' ' -f1)
        stale_files+=("  $sr_file (English: $en_date, Serbian: $sr_date)")
      fi
    else
      missing_files+=("  $root_file")
    fi
  fi
done

# Per-domain stats
echo "By domain:"
for domain in "${DOMAINS[@]}"; do
  domain_en=0
  domain_sr=0

  while IFS= read -r file; do
    # Skip excluded files
    basename_file=$(basename "$file")
    skip=false
    for excl in "${EXCLUDED_FILES[@]}"; do
      if [ "$basename_file" = "$excl" ]; then
        skip=true
        break
      fi
    done
    if [ "$skip" = true ]; then continue; fi

    domain_en=$((domain_en + 1))
    total_en=$((total_en + 1))

    sr_file="${file%.md}.sr.md"
    if [ -f "$sr_file" ]; then
      domain_sr=$((domain_sr + 1))
      total_sr=$((total_sr + 1))
      # Check staleness
      en_ts=$(git log -1 --format=%ct -- "$file" 2>/dev/null || echo 0)
      sr_ts=$(git log -1 --format=%ct -- "$sr_file" 2>/dev/null || echo 0)
      if [ "$en_ts" -gt "$sr_ts" ] 2>/dev/null; then
        en_date=$(git log -1 --format=%ci -- "$file" 2>/dev/null | cut -d' ' -f1)
        sr_date=$(git log -1 --format=%ci -- "$sr_file" 2>/dev/null | cut -d' ' -f1)
        stale_files+=("  $sr_file (English: $en_date, Serbian: $sr_date)")
      fi
    else
      missing_files+=("  $file")
    fi
  done < <(find "$domain" -name "*.md" ! -name "*.sr.md" | sort)

  if [ "$domain_en" -gt 0 ]; then
    pct=$((domain_sr * 100 / domain_en))
    printf "  %-16s %3d/%-3d (%d%%)\n" "$domain:" "$domain_sr" "$domain_en" "$pct"
  fi
done

echo ""
if [ "$total_en" -gt 0 ]; then
  pct=$((total_sr * 100 / total_en))
else
  pct=0
fi
echo "Overall: $total_sr/$total_en files translated ($pct%)"

if [ ${#missing_files[@]} -gt 0 ]; then
  echo ""
  echo "Missing translations (${#missing_files[@]}):"
  printf '%s\n' "${missing_files[@]}"
fi

if [ ${#stale_files[@]} -gt 0 ]; then
  echo ""
  echo "Potentially stale (${#stale_files[@]}):"
  printf '%s\n' "${stale_files[@]}"
fi

echo ""
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x scripts/translation-coverage.sh`

- [ ] **Step 3: Test the coverage script**

Run: `bash scripts/translation-coverage.sh`
Expected: Shows 0/199 files translated (0%), lists all files as missing. No errors.

- [ ] **Step 4: Commit**

```bash
git add scripts/translation-coverage.sh
git commit -m "feat: add translation coverage report script"
```

## Phase 2: Root Documents (Task 4)

### Task 4: Translate root documents

**Files:**
- Create: `README.sr.md`
- Create: `TOPIC_TEMPLATE.sr.md`

- [ ] **Step 1: Translate README.md to README.sr.md**

Read `README.md` and create `README.sr.md` with:
- All explanatory text translated to Serbian (Latin script)
- Table links pointing to `questions.sr.md` (e.g., `[architecture/](architecture/questions.sr.md)`)
- Badge URLs kept as-is
- License/Contributing links kept pointing to English versions (those aren't translated)

- [ ] **Step 2: Translate TOPIC_TEMPLATE.md to TOPIC_TEMPLATE.sr.md**

Read `TOPIC_TEMPLATE.md` and create `TOPIC_TEMPLATE.sr.md` with:
- Section headers translated (e.g., "Core Idea" -> "Osnovna ideja", "Key Points" -> "Ključne tačke", "Example" -> "Primer", "Common Interview Questions" -> "Česta pitanja na intervjuu", "Conclusion" -> "Zaključak")
- Placeholder text translated
- Code block kept in English
- Cross-reference format shown with `.sr.md` links

- [ ] **Step 3: Commit**

```bash
git add README.sr.md TOPIC_TEMPLATE.sr.md
git commit -m "feat: add Serbian translations for root documents"
```

## Phase 3: Index Files (Task 5)

### Task 5: Translate all 13 questions.md index files

**Files:**
- Create: `architecture/questions.sr.md`
- Create: `caching/questions.sr.md`
- Create: `ddd/questions.sr.md`
- Create: `general/questions.sr.md`
- Create: `highload/questions.sr.md`
- Create: `javascript/questions.sr.md`
- Create: `microservices/questions.sr.md`
- Create: `mysql/questions.sr.md`
- Create: `oop/questions.sr.md`
- Create: `php/questions.sr.md`
- Create: `solid/questions.sr.md`
- Create: `symfony/questions.sr.md`
- Create: `testing/questions.sr.md`

- [ ] **Step 1: Translate all questions.md files**

For each domain, read the `questions.md` and create a `questions.sr.md` with:
- Title translated (e.g., "Architecture questions" -> "Pitanja o arhitekturi")
- Link text translated to Serbian
- Link targets changed to `.sr.md` (e.g., `[CQRS](cqrs.md)` -> `[CQRS](cqrs.sr.md)`)
- Any descriptive text translated

This can be done in parallel — one agent per batch of domains, since there are no dependencies between index files.

**Batch A (large domains):** general, oop, php
**Batch B (medium domains):** microservices, symfony, testing, highload
**Batch C (small domains):** architecture, caching, ddd, mysql, solid, javascript

- [ ] **Step 2: Verify all links are correctly rewritten**

Run: `grep -r '\.md)' */questions.sr.md | grep -v '\.sr\.md)' | grep -v 'CONTRIBUTING' | grep -v 'TOPIC_TEMPLATE'`
Expected: No output (all internal links should point to `.sr.md` files)

- [ ] **Step 3: Commit**

```bash
git add */questions.sr.md
git commit -m "feat: add Serbian translations for all questions.md index files"
```

## Phase 4: Topic File Translations (Tasks 6-14)

Each task translates one domain's topic files. These are independent and can be run in parallel using subagents. Each subagent should:

1. Read each English `.md` file in the domain
2. Create the corresponding `.sr.md` file with:
   - All explanatory text translated to Serbian (Latin script)
   - Code blocks kept entirely in English (including comments)
   - Internal links rewritten to `.sr.md` targets
   - Technical terms kept in English where universally used in Serbian dev communities
3. Verify no English-target links remain in `.sr.md` files

**Translation rules reminder for each agent:**
- Script: Serbian Latin (Latinica) only. Never Cyrillic.
- Code blocks: Keep entirely in English
- Section headers: Translate consistently (use same translations as TOPIC_TEMPLATE.sr.md)
- Links: All internal links must point to `.sr.md` files
- Technical terms: Keep English for universally used terms (dependency injection, singleton, factory, etc.)

### Task 6: Translate general domain (19 topic files)

**Files to create:**
- `general/concurrency_vs_parallelism.sr.md`
- `general/cors.sr.md`
- `general/csrf.sr.md`
- `general/data_structures_overview.sr.md`
- `general/how_authentication_works.sr.md`
- `general/how_authorization_works.sr.md`
- `general/how_internet_works.sr.md`
- `general/how_jwt_authorization_works.sr.md`
- `general/http_4xx_vs_5xx_errors.sr.md`
- `general/http_protocol_structure.sr.md`
- `general/http_streaming.sr.md`
- `general/owasp_top_10.sr.md`
- `general/rest_api_architecture.sr.md`
- `general/rest_api_post_vs_put_vs_patch.sr.md`
- `general/rest_api_put_request_specification.sr.md`
- `general/rest_api_vs_json_rpc.sr.md`
- `general/soa_architecture.sr.md`
- `general/soap_vs_rest.sr.md`
- `general/web_application_attacks.sr.md`

- [ ] **Step 1: Translate all 19 topic files**

Read each English file, create `.sr.md` counterpart following translation rules.

- [ ] **Step 2: Verify links**

Run: `grep -r '\.md)' general/*.sr.md | grep -v '\.sr\.md)'`
Expected: No output

- [ ] **Step 3: Commit**

```bash
git add general/*.sr.md
git commit -m "feat: add Serbian translations for general domain"
```

### Task 7: Translate oop domain (35 topic files)

**Files to create (root level):**
- `oop/abstract_classes_vs_interfaces.sr.md`
- `oop/active_record_vs_data_mapper.sr.md`
- `oop/anemic_model.sr.md`
- `oop/composition_vs_aggregation.sr.md`
- `oop/composition_vs_inheritance.sr.md`
- `oop/design_patterns_in_php_frameworks.sr.md`
- `oop/di_vs_composition_vs_ioc.sr.md`
- `oop/dto_vs_command.sr.md`
- `oop/entity_vs_data_transfer_object_vs_value_object.sr.md`
- `oop/grasp.sr.md`
- `oop/immutable_objects.sr.md`
- `oop/invariance_vs_covariance_vs_contravariance.sr.md`
- `oop/kiss_dry_yagni.sr.md`
- `oop/lod.sr.md`
- `oop/mvc_pattern.sr.md`
- `oop/oop_main_definitions.sr.md`
- `oop/polymorphism_vs_inheritance.sr.md`
- `oop/positive_examples_of_singleton_pattern_usage.sr.md`
- `oop/refactoring_legacy_code.sr.md`
- `oop/registry_pattern_vs_service_locator.sr.md`
- `oop/service_locator_vs_di_container.sr.md`
- `oop/soc.sr.md`
- `oop/stateless_service.sr.md`
- `oop/what_is_an_objects_behavior.sr.md`
- `oop/why_getter_and_setters_are_bad.sr.md`

**Files to create (design_patterns/):**
- `oop/design_patterns/adapter.sr.md`
- `oop/design_patterns/command_bus.sr.md`
- `oop/design_patterns/data_mapper.sr.md`
- `oop/design_patterns/decorator.sr.md`
- `oop/design_patterns/factory.sr.md`
- `oop/design_patterns/list_of_design_patterns.sr.md`
- `oop/design_patterns/observer.sr.md`
- `oop/design_patterns/proxy.sr.md`
- `oop/design_patterns/singleton.sr.md`
- `oop/design_patterns/strategy.sr.md`

- [ ] **Step 1: Translate all 35 topic files**
- [ ] **Step 2: Verify links**

Run: `grep -r '\.md)' oop/*.sr.md oop/design_patterns/*.sr.md | grep -v '\.sr\.md)'`
Expected: No output

- [ ] **Step 3: Commit**

```bash
git add oop/*.sr.md oop/design_patterns/*.sr.md
git commit -m "feat: add Serbian translations for oop domain"
```

### Task 8: Translate php domain (33 topic files)

**Files to create:**
- `php/calling_object_destructor_vs_garbage_collector.sr.md`
- `php/cases_of_passing_variable_by_reference_by_default.sr.md`
- `php/closure_vs_anonymous_function.sr.md`
- `php/composer.sr.md`
- `php/data_types_in_php.sr.md`
- `php/generators.sr.md`
- `php/how_sessions_work.sr.md`
- `php/immutable_objects_in_php.sr.md`
- `php/interfaces.sr.md`
- `php/invoke_method_useful_examples.sr.md`
- `php/late_static_bindings.sr.md`
- `php/magic_constants.sr.md`
- `php/magic_methods.sr.md`
- `php/main_risks_of_using_php_as_daemon_and_how_to_manage_them.sr.md`
- `php/multiple_inheritance_in_php.sr.md`
- `php/new_features_in_php7.sr.md`
- `php/new_features_in_php74.sr.md`
- `php/new_features_in_php80.sr.md`
- `php/new_features_in_php81.sr.md`
- `php/new_features_in_php82.sr.md`
- `php/new_features_in_php83.sr.md`
- `php/new_features_in_php84.sr.md`
- `php/new_features_in_php85.sr.md`
- `php/persistent_database_connections.sr.md`
- `php/php_arrays_internals.sr.md`
- `php/popular_spl_functions.sr.md`
- `php/reflection_practical_usage_examples.sr.md`
- `php/this_vs_self_vs_parent.sr.md`
- `php/traits.sr.md`
- `php/tricky_questions.sr.md`
- `php/what_is_autoload_in_php_and_composer.sr.md`
- `php/what_is_opcache.sr.md`
- `php/yield_from_syntax.sr.md`

- [ ] **Step 1: Translate all 33 topic files**
- [ ] **Step 2: Verify links**

Run: `grep -r '\.md)' php/*.sr.md | grep -v '\.sr\.md)'`
Expected: No output

- [ ] **Step 3: Commit**

```bash
git add php/*.sr.md
git commit -m "feat: add Serbian translations for php domain"
```

### Task 9: Translate architecture domain (5 topic files)

**Files to create:**
- `architecture/cqrs.sr.md`
- `architecture/event_sourcing.sr.md`
- `architecture/hexagonal_architecture.sr.md`
- `architecture/onion_architecture.sr.md`
- `architecture/reactor_pattern.sr.md`

- [ ] **Step 1: Translate all 5 topic files**
- [ ] **Step 2: Verify links**

Run: `grep -r '\.md)' architecture/*.sr.md | grep -v '\.sr\.md)'`
Expected: No output

- [ ] **Step 3: Commit**

```bash
git add architecture/*.sr.md
git commit -m "feat: add Serbian translations for architecture domain"
```

### Task 10: Translate microservices domain (21 topic files)

**Files to create:**
- `microservices/answers/advantages_of_microservices.sr.md`
- `microservices/answers/best_practices_for_microservices_development.sr.md`
- `microservices/answers/challenges_of_microservices.sr.md`
- `microservices/answers/ci_cd_in_microservices.sr.md`
- `microservices/answers/cost_management_and_optimization.sr.md`
- `microservices/answers/data_management_in_microservices.sr.md`
- `microservices/answers/decentralized_data_management.sr.md`
- `microservices/answers/evolutionary_design_in_microservices.sr.md`
- `microservices/answers/future_trends_in_microservices_architecture.sr.md`
- `microservices/answers/microservices_and_cloud_compatibility.sr.md`
- `microservices/answers/microservices_characteristics.sr.md`
- `microservices/answers/microservices_communication_patterns.sr.md`
- `microservices/answers/microservices_deployment_strategies.sr.md`
- `microservices/answers/microservices_security_patterns.sr.md`
- `microservices/answers/microservices_vs_monolith.sr.md`
- `microservices/answers/monitoring_and_logging_in_microservices.sr.md`
- `microservices/answers/observability_in_microservices.sr.md`
- `microservices/answers/organizational_impact_and_team_structures.sr.md`
- `microservices/answers/scaling_microservices.sr.md`
- `microservices/answers/service_discovery_in_microservices.sr.md`
- `microservices/answers/testing_strategies_for_microservices.sr.md`

- [ ] **Step 1: Translate all 21 topic files**
- [ ] **Step 2: Verify links**

Run: `grep -r '\.md)' microservices/answers/*.sr.md | grep -v '\.sr\.md)'`
Expected: No output

- [ ] **Step 3: Commit**

```bash
git add microservices/answers/*.sr.md
git commit -m "feat: add Serbian translations for microservices domain"
```

### Task 11: Translate small domains batch A — solid + ddd + mysql (19 topic files)

**Files to create (solid — 5 files):**
- `solid/answers/dependency_inversion_principle.sr.md`
- `solid/answers/interface_segregation_principle.sr.md`
- `solid/answers/liskov_substitution_principle.sr.md`
- `solid/answers/open_closed_principle.sr.md`
- `solid/answers/single_responsibility_principle.sr.md`

**Files to create (ddd — 8 files):**
- `ddd/answers/acl.sr.md`
- `ddd/answers/aggregates.sr.md`
- `ddd/answers/bounded_contexts.sr.md`
- `ddd/answers/domain_events.sr.md`
- `ddd/answers/entities_and_value_objects.sr.md`
- `ddd/answers/layers.sr.md`
- `ddd/answers/repositories.sr.md`
- `ddd/answers/ubiquitous_language.sr.md`

**Files to create (mysql — 6 files):**
- `mysql/acid_transactions.sr.md`
- `mysql/answers/data_types_and_sql_concepts.sr.md`
- `mysql/answers/engines.sr.md`
- `mysql/answers/indices.sr.md`
- `mysql/entity_relationships.sr.md`
- `mysql/explain_query_analysis.sr.md`

- [ ] **Step 1: Translate all 19 topic files across solid, ddd, mysql**
- [ ] **Step 2: Verify links**

Run: `grep -r '\.md)' solid/answers/*.sr.md ddd/answers/*.sr.md mysql/*.sr.md mysql/answers/*.sr.md | grep -v '\.sr\.md)'`
Expected: No output

- [ ] **Step 3: Commit**

```bash
git add solid/answers/*.sr.md ddd/answers/*.sr.md mysql/*.sr.md mysql/answers/*.sr.md
git commit -m "feat: add Serbian translations for solid, ddd, and mysql domains"
```

### Task 12: Translate testing domain (12 topic files)

**Files to create:**
- `testing/bdd.sr.md`
- `testing/how_mocks_work_under_the_hood.sr.md`
- `testing/how_to_mock_an_object_property_that_was_created_internally_inside_constructor_method.sr.md`
- `testing/how_to_mock_external_api_two_ways.sr.md`
- `testing/how_to_mock_static_method.sr.md`
- `testing/mocking_database_connection.sr.md`
- `testing/mocking_doctrine_repositories.sr.md`
- `testing/mocking_final_classes.sr.md`
- `testing/mutational_testing_tools_and_benefits.sr.md`
- `testing/symfony_testing_settings.sr.md`
- `testing/tdd.sr.md`
- `testing/test_environment_preparation.sr.md`

- [ ] **Step 1: Translate all 12 topic files**
- [ ] **Step 2: Verify links**

Run: `grep -r '\.md)' testing/*.sr.md | grep -v '\.sr\.md)'`
Expected: No output

- [ ] **Step 3: Commit**

```bash
git add testing/*.sr.md
git commit -m "feat: add Serbian translations for testing domain"
```

### Task 13: Translate highload domain (11 topic files)

**Files to create:**
- `highload/circuit_breaker_pattern.sr.md`
- `highload/deadlocks_in_mysql.sr.md`
- `highload/how_to_narrow_problems_on_php_side_of_an_application.sr.md`
- `highload/how_to_optimize_single_insert_in_a_big_table.sr.md`
- `highload/load_balancer_and_sessions.sr.md`
- `highload/optimistic_pessimistic_lock.sr.md`
- `highload/optimizing_slow_get_endpoint.sr.md`
- `highload/partitioning.sr.md`
- `highload/php_fpm.sr.md`
- `highload/sharding.sr.md`
- `highload/tools_for_analyzing_problems_on_database_side_of_an_application.sr.md`

- [ ] **Step 1: Translate all 11 topic files**
- [ ] **Step 2: Verify links**

Run: `grep -r '\.md)' highload/*.sr.md | grep -v '\.sr\.md)'`
Expected: No output

- [ ] **Step 3: Commit**

```bash
git add highload/*.sr.md
git commit -m "feat: add Serbian translations for highload domain"
```

### Task 14: Translate small domains batch B — symfony + caching + javascript (24 topic files)

**Files to create (symfony — 21 files):**
- `symfony/answers/autoconfigure.sr.md`
- `symfony/answers/autowire_two_instances_same_service.sr.md`
- `symfony/answers/autowiring.sr.md`
- `symfony/answers/avoiding_cyclic_references_in_serialization.sr.md`
- `symfony/answers/compiler_pass_in_symfony.sr.md`
- `symfony/answers/components/dependency_injection_component.sr.md`
- `symfony/answers/components/event_dispatcher_component.sr.md`
- `symfony/answers/components/httpkernel_component.sr.md`
- `symfony/answers/components/messenger_component.sr.md`
- `symfony/answers/components/security_component.sr.md`
- `symfony/answers/components/serialization_component.sr.md`
- `symfony/answers/components/validator_component.sr.md`
- `symfony/answers/design_patterns_in_symfony_and_doctrine.sr.md`
- `symfony/answers/lazy_loading_for_classes.sr.md`
- `symfony/answers/request_response_lifecycle.sr.md`
- `symfony/answers/symfony_flex_explanation.sr.md`
- `symfony/answers/symfony_kernel_events_explanation.sr.md`
- `symfony/answers/symfony_routing_explanation.sr.md`
- `symfony/answers/sync_vs_async_transport_symfony_messenger.sr.md`
- `symfony/answers/validating_requests_in_symfony.sr.md`
- `symfony/answers/writing_rest_api_in_symfony.sr.md`

**Files to create (caching — 4 files):**
- `caching/caching_best_practices.sr.md`
- `caching/memcache_vs_memcached.sr.md`
- `caching/memcached_vs_redis.sr.md`
- `caching/redis_basics.sr.md`

**Files to create (javascript — 2 files):**
- `javascript/async_javascript.sr.md`
- `javascript/js_fundamentals.sr.md`

- [ ] **Step 1: Translate all 27 topic files across symfony, caching, javascript**
- [ ] **Step 2: Verify links**

Run: `grep -r '\.md)' symfony/answers/*.sr.md symfony/answers/components/*.sr.md caching/*.sr.md javascript/*.sr.md | grep -v '\.sr\.md)'`
Expected: No output

- [ ] **Step 3: Commit**

```bash
git add symfony/answers/*.sr.md symfony/answers/components/*.sr.md caching/*.sr.md javascript/*.sr.md
git commit -m "feat: add Serbian translations for symfony, caching, and javascript domains"
```

## Phase 5: Final Verification (Task 15)

### Task 15: Run coverage report and verify completeness

- [ ] **Step 1: Run coverage report**

Run: `bash scripts/translation-coverage.sh`
Expected: 197/197 files translated (100%), no missing translations, no stale translations.

- [ ] **Step 2: Run markdown linting on all .sr.md files**

Run: `npx markdownlint-cli2 '**/*.sr.md'`
Expected: No errors (or only pre-existing style issues matching English files).

- [ ] **Step 3: Verify no English-target links remain in any .sr.md file**

Run: `grep -r '\.md)' . --include='*.sr.md' | grep -v '\.sr\.md)' | grep -v 'CONTRIBUTING' | grep -v 'LICENSE'`
Expected: No output.

- [ ] **Step 4: Fix any issues found in steps 1-3**

- [ ] **Step 5: Final commit if fixes were needed**

```bash
git add -A '*.sr.md'
git commit -m "fix: resolve translation coverage and linting issues"
```

## Parallel Execution Strategy

Tasks 6-14 are fully independent and should be run in parallel using subagents. Recommended grouping for maximum parallelism:

| Agent | Tasks | Files | Domains |
|-------|-------|-------|---------|
| Agent 1 | Task 6 | 19 | general |
| Agent 2 | Task 7 | 35 | oop |
| Agent 3 | Task 8 | 33 | php |
| Agent 4 | Task 9 + Task 13 | 16 | architecture + highload |
| Agent 5 | Task 10 | 21 | microservices |
| Agent 6 | Task 11 | 19 | solid + ddd + mysql |
| Agent 7 | Task 12 | 12 | testing |
| Agent 8 | Task 14 | 27 | symfony + caching + javascript |

This gives 8 parallel agents with roughly balanced workloads (12-35 files each).
