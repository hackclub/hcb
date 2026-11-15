#!/usr/bin/env bash
# PreToolUse hook for Write: block creating new migration files by hand. Editing a
# migration that already exists (e.g. one a generator just created) is allowed.
#
# Claude Code sends the tool call as JSON on stdin. jq is fastest; Ruby (which this
# repo requires anyway) is the fallback so the hook never silently fails open.
if command -v jq >/dev/null 2>&1; then
  path=$(jq -r '.tool_input.file_path // empty')
else
  path=$(ruby --disable-gems -rjson -e 'puts JSON.parse($stdin.read).dig("tool_input", "file_path").to_s')
fi

case "$path" in
  "${CLAUDE_PROJECT_DIR:-$PWD}"/db/migrate/*) ;;
  *) exit 0 ;;
esac
[ -e "$path" ] && exit 0

echo "Don't hand-write migration files. Generate it with a Rails generator (e.g. \`bin/rails generate migration AddFooToBars foo:string\` or \`bin/rails generate model ...\`) so it gets a correct timestamp, then edit the generated file. See https://guides.rubyonrails.org/active_record_migrations.html#generating-migration-files for more information." >&2
exit 2
