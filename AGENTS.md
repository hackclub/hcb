# Instructions for coding agents

## Never force push

Do not run `git push --force`, `git push --force-with-lease`, `git push -f`, or anything else that rewrites history on a remote branch, unless the user explicitly asks for that exact command in this conversation. This includes rebasing or amending commits that have already been pushed and then pushing the result.

Force pushing is never part of the normal workflow here. HCB updates feature branches by merging `main` into them, not by rebasing, so review comments stay attached to the right commits (see [`dev-docs/pull_requests.md`](dev-docs/pull_requests.md)).

If a push is rejected because the remote branch has commits you do not have, fetch and merge them, then push normally. If that still fails, stop and tell the user instead of forcing the push.

## Working in this repo

- Read [`dev-docs/development.md`](dev-docs/development.md) for setup and [`dev-docs/code_style.md`](dev-docs/code_style.md) for conventions that CI does not enforce.
- Follow [`dev-docs/pull_requests.md`](dev-docs/pull_requests.md): use the PR template, keep commits small, and merge `main` into your branch rather than rebasing.
- Run `bin/lint -c` before pushing. CI runs RuboCop, ERB Lint, ESLint, Prettier, and Herb.
