---
name: migrate-from-gha
metadata:
  version: "0.1.6"
description: >-
  Migrate a GitHub Actions workflow to RWX. Translates triggers, jobs, steps
  into an optimized RWX config with DAG parallelism, content-based caching, and
  RWX packages. TRIGGER when: the user asks to migrate, convert, or translate a
  GitHub Actions workflow to RWX.
argument-hint: [path/to/.github/workflows/ci.yml]
---

## Migration Procedure

You are migrating a GitHub Actions workflow to RWX. Follow these steps exactly.
Do NOT use TodoWrite — this procedure is your task list.

### Step 1: Read and analyze the source workflow

Read the GitHub Actions workflow file at `$ARGUMENTS`. If no path is provided,
look for `.github/workflows/` and list the available workflow files for the user
to choose from.

Identify all jobs and their `needs:` dependencies, all steps within each job,
triggers (`on:` events), secrets referenced (`${{ secrets.* }}`), environment
variables (`env:` blocks at workflow, job, and step level), matrix strategies,
services, composite action references, reusable workflow calls, artifact
upload/download steps, and cache steps (these will be removed — RWX handles
caching natively).

For steps using `uses: ./.github/actions/foo`, read that action's `action.yml`
and inline its logic into the translated RWX config. For cross-repo references
(`uses: org/repo@ref`), add a `# TODO:` comment explaining what the action does
and that the user needs to translate it manually or find an RWX package
equivalent.

Tell the user what you found: how many jobs, the dependency graph between them,
which triggers are configured, which composite actions you inlined, and which
cross-repo references will need TODO comments. Keep it brief.

Then write a migration inventory to `.rwx/.migration-inventory.md`. This file is
a structured checklist that will be used during the review step to verify
nothing was dropped. Keep it compact — names and keys only, not full details:

```markdown
## Jobs

- lint (needs: [])
- test (needs: [])
- build (needs: [lint, test])
- deploy (needs: [build], if: github.ref == 'refs/heads/main')

## Secrets

- DEPLOY_TOKEN

## Environment Variables

- DATABASE_URL (job: test)

## Services

- postgres (job: test)

## Matrix Strategies

- go-version: [1.22, 1.26] (job: test)

## Notable Steps

- golangci-lint-action (job: lint)
- upload-artifact coverage.out (job: test)
- download-artifact app-binary (job: deploy)
```

Omit any sections that have no entries.

### Step 2: Write the optimized RWX config

Fetch the full reference documentation now. Do NOT use WebFetch — it summarizes
and drops critical details. Instead, use Bash to run `rwx docs pull` for each
doc and read stdout directly. Run all three in a single turn as parallel Bash
calls:

- `rwx docs pull /docs/rwx/migrating/gha-cheat-sheet` — action-to-package
  mapping and DAG pattern (read this first)
- `rwx docs pull /docs/rwx/migrating/rwx-reference` — full RWX config syntax
- `rwx docs pull /docs/rwx/migrating/gha-reference` — GHA-to-RWX concept mapping

If you encounter a question not covered by these references, use
`rwx docs search "<query>"` to find the relevant documentation page, then
`rwx docs pull` the result.

This is the core of the migration. Do NOT produce a 1:1 mapping. Apply the
optimization rules from the reference documentation — including DAG
decomposition, content-based caching, package substitution, trigger mapping,
secret mapping, and environment variable translation.

If the source workflow uses `on: workflow_run` (triggered after another workflow
completes), translate this to an RWX **embedded run** — a run config nested
inside the parent workflow's config. Consult the reference docs for embedded run
syntax. Do not fall back to dispatch triggers or conditional push triggers for
this case.

Look for parallelism opportunities _within_ individual GHA jobs, not just across
jobs. If a single job contains multiple independent steps (e.g., eslint,
prettier, and openapi validation in a "lint" job), split them into separate RWX
tasks that can run in parallel rather than combining them into one sequential
`run:` block.

Separate install and build into distinct tasks. When a GHA job runs `npm ci` (or
similar) followed by a build step (e.g., `npm run build` for a shared package),
these should be two separate RWX tasks so the build can be cached independently.
If the same build command appears in multiple GHA jobs, produce a single shared
build task in the DAG rather than duplicating it.

If the source workflow contains `docker build` steps, use AskUserQuestion to ask
whether they'd like to use **RWX OCI images** instead. Explain the tradeoffs:
OCI images leverage RWX's native image building with content-based caching and
no Docker daemon dependency, but require adopting RWX-specific configuration.
Consult the cheat sheet for OCI image details. Respect the user's choice — if
they prefer to keep `docker build`, translate it directly.

Write the generated RWX config to `.rwx/<name>.yml`, where `<name>` is derived
from the source workflow filename (e.g., `ci.github.yml` → `.rwx/ci.yml`).

Structure the file in this order:

1. `on:` triggers
2. `base:` image and config
3. `tool-cache:` (if needed)
4. `tasks:` array, ordered by dependency depth (independent tasks first, then
   their dependents)

After writing the file, validate the generated config:

    rwx lint .rwx/<name>.yml

If there are diagnostics, fix the issues and re-check until the file is clean.
You can also initiate test runs locally without pushing the code — see
`rwx run --help` for documentation.

### Step 3: Review and summarize

Tell the user: "Now reviewing the migration to check for gaps."

Re-read `.rwx/.migration-inventory.md` (written in Step 1) and the generated RWX
config. Use the inventory as your checklist — verify every item in it is
accounted for in the config. This is more reliable than working from memory of
the source workflow.

Then follow the review procedure from
[review-gha-migration/SKILL.md](../review-gha-migration/SKILL.md). You already
have the reference docs from Step 2 — do not re-fetch them.

If the review found blocking issues, fix them before continuing.

Then provide a final summary to the user that covers both the migration and the
review:

- What the original workflow did
- How the RWX version is structured differently (and why it's better)
- The DAG shape: which tasks run in parallel vs sequentially
- The review verdict and any issues found (or confirmation that it passed)
- Any `# TODO:` items that need manual attention
- Secrets that need to be configured in RWX Cloud
- Estimated parallelism improvement (e.g., "6 sequential steps → 3 parallel
  stages")

Let the user know they can re-run the review independently at any time with
`/review-gha-migration`.
