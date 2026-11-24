---
name: review-gha-migration
metadata:
  version: "0.1.6"
description: >-
  Review an RWX config generated from a GitHub Actions migration. Compares the
  source workflow against the generated config to catch semantic gaps, missing
  steps, and optimization opportunities. TRIGGER when: the user asks to review,
  validate, or check an RWX config that was migrated from GitHub Actions.
argument-hint: [.rwx/ci.yml]
---

## Quick Reference

Fetch and read the cheat sheet before starting. Do NOT use WebFetch — it
summarizes and drops critical details. Instead, use Bash to run `rwx docs pull`
and read stdout directly:

    rwx docs pull /docs/rwx/migrating/gha-cheat-sheet

## Review Procedure

You are reviewing an RWX config that was generated from a GitHub Actions
workflow migration. Your job is to catch problems the implementer missed.
Approach this as a skeptical reviewer, not as someone defending prior work.

### Step 1: Identify the files

The user provides the RWX config path as `$ARGUMENTS`. If no path is provided,
list the files in `.rwx/` and ask the user which config to review.

Then locate the corresponding source GitHub Actions workflow. Look for clues:

- Comments in the RWX config referencing the source file
- Filename correspondence (e.g., `.rwx/ci.yml` likely came from
  `.github/workflows/ci.yml`)
- Ask the user if the source is ambiguous

Read both files in full.

### Step 2: Inventory the source workflow

Build a checklist from the GitHub Actions workflow. For each item, you will
verify it was correctly translated. Extract:

- Every job and its `needs:` dependencies
- Every step within each job (name + what it does)
- All triggers and their configurations (branches, paths, event types)
- Every secret referenced
- Every environment variable (workflow, job, and step level)
- Matrix strategies and their dimensions
- Services (databases, caches, etc.)
- Artifact upload/download pairs
- Caching steps
- Composite action references
- Reusable workflow calls
- Conditional logic (`if:` expressions)
- Timeout and concurrency settings

### Step 3: Verify behavioral equivalence

Go through your checklist item by item and verify each one is accounted for in
the RWX config. For each item, classify it as:

- **Correct** — properly translated to the RWX equivalent
- **Missing** — not present in the RWX config and no TODO comment explaining why
- **Wrong** — translated but with a semantic difference that changes behavior
- **Degraded** — works but lost important properties (e.g., a parallel job
  became sequential)

Pay special attention to:

- Steps that were silently dropped during migration
- `if:` conditionals that were lost or simplified incorrectly
- Environment variables that were not carried over
- Secrets that are referenced but not mapped
- Matrix dimensions that were flattened or lost
- Service containers that have no equivalent
- Artifact passing between jobs that was not preserved

### Step 4: Verify RWX optimizations

If you don't already have the reference documentation in context, fetch it now.
Do NOT use WebFetch — it summarizes and drops critical details. Instead, use
Bash to run `rwx docs pull` for each doc and read stdout directly. Run both in a
single turn as parallel Bash calls:

- `rwx docs pull /docs/rwx/migrating/rwx-reference` — full RWX config syntax
- `rwx docs pull /docs/rwx/migrating/gha-reference` — GHA-to-RWX concept mapping

If you encounter a question not covered by these references, use
`rwx docs search "<query>"` to find the relevant documentation page, then
`rwx docs pull` the result.

Using the reference documentation, check whether the config takes full advantage
of RWX capabilities:

- **DAG structure**: Are tasks that can run in parallel actually parallel, or
  are there unnecessary sequential dependencies?
- **Content-based caching**: Are cache keys content-based (not hash-based) where
  possible?
- **Package substitution**: Are there `run:` steps installing tools that have
  RWX package equivalents?
- **Task granularity**: Could large monolithic tasks be split into parallel
  subtasks? In particular, flag install tasks that also contain build commands
  (e.g., `npm ci` followed by `npm run build`) — these should be separate tasks
  for independent cacheability.
- **Trigger optimization**: Are triggers using path filters and branch filters
  effectively?

### Step 5: Validate structure

Check the RWX config for structural issues:

- Required fields are present
- YAML is well-formed
- Task ordering reflects the DAG (independent tasks first)
- No orphaned `use` references
- Run `rwx lint .rwx/<name>.yml` and review the diagnostics

### Step 6: Produce the review

Output a structured review with these sections:

**Summary**: One-line verdict — is this migration correct and ready, or does it
need changes?

**Issues** (if any): A numbered list of problems found, each with:

- Severity: `blocking` (must fix before using) or `suggestion` (improvement
  opportunity)
- What's wrong
- Where in the RWX config it occurs
- What the fix should be

**Checklist**: A markdown checklist showing each source workflow item and
whether it was correctly translated:

```
- [x] Job: build — correctly translated as task `build`
- [ ] Job: deploy — missing, no TODO comment
- [x] Trigger: push to main — correctly mapped
- [ ] Secret: DEPLOY_KEY — referenced but not in secrets mapping
```

**Optimization opportunities**: Any RWX-specific improvements not yet applied.

If you find blocking issues, offer to fix them directly.
