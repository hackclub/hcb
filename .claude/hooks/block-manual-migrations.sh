#!/usr/bin/env bash
# PreToolUse hook for Write: block creating new migration files by hand. Editing a
# migration that already exists (e.g. one a generator just created) is allowed.
path=$(jq -r '.tool_input.file_path // empty')
case "$path" in
  */db/migrate/*|db/migrate/*) ;;
  *) exit 0 ;;
esac
[ -e "$path" ] && exit 0

echo "Don't hand-write migration files. Generate it with a Rails generator (e.g. \`bin/rails generate migration AddFooToBars foo:string\` or \`bin/rails generate model ...\`) so it gets a correct timestamp, then edit the generated file." >&2
exit 2
