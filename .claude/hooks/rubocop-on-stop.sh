#!/usr/bin/env bash
# Stop hook: run RuboCop on Ruby files changed in the working tree. If there are
# offenses, exit 2 so Claude is blocked from stopping and sees the output.
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}" || exit 0

mapfile -t files < <(
  { git diff --name-only --diff-filter=d HEAD; git ls-files --others --exclude-standard; } |
    sort -u | grep -E '(\.(rb|rake|jbuilder|gemspec|ru)|^Gemfile|/Gemfile)$'
)
[ ${#files[@]} -eq 0 ] && exit 0

errfile=$(mktemp)
trap 'rm -f "$errfile"' EXIT
output=$(bin/rubocop --force-exclusion --format simple "${files[@]}" 2>"$errfile")
status=$?

case $status in
  0) exit 0 ;;
  1) echo "RuboCop found offenses in changed files. Fix them (bin/rubocop -a can autocorrect many) before finishing:" >&2
     echo "$output" >&2 ;;
  # RuboCop itself failed; stderr also carries the noisy pending-cops notice, so only show it here
  *) echo "RuboCop failed to run (exit $status):" >&2
     echo "$output" >&2
     cat "$errfile" >&2 ;;
esac
exit 2
