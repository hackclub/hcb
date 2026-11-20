# frozen_string_literal: true

# PreToolUse hook for Bash: block force pushes so an agent can never rewrite
# history on a remote branch. HCB updates feature branches by merging main into
# them, not rebasing, so a force push is never part of the normal workflow.
#
# This is a regex over the command text, so it is a guard rather than a
# guarantee. A git alias, a shell variable or `$(...)` that expands to the flag,
# or a script that calls git internally will get past it. Branch protection on
# GitHub is the only thing that can forbid force pushes outright.
#
# Claude Code sends the tool call as JSON on stdin. Run with `ruby --disable-gems`
# so it starts in a few milliseconds.
require "json"

begin
  command = JSON.parse($stdin.read).dig("tool_input", "command")
rescue JSON::ParserError => e
  warn "block-force-push hook could not parse the tool input: #{e.message}"
  exit 2
end
exit 0 if command.nil? || command.empty?

# Drop quotes so `git push "--force"`, `git -C "my dir" push -f`, and
# `sh -c 'git push --force'` look like their unquoted forms.
command = command.delete(%q('"))

# `git push`, allowing options between the two words such as `git -C dir push`,
# `git -c key=val push`, or `git --no-pager push`.
GIT_PUSH = /\bgit\s+(?:-[^;|&\n]*?\s+)?push\b/

# Shell separators that end one command and start the next. A lone `&` is left
# alone so a redirect like `2>&1` does not cut the command short.
SEPARATOR = /;|&&|\|\||\||\n/

# Force variants: --force, --force-with-lease[=...], --force-if-includes, -f,
# combined short flags that include f (-uf, -fu), a `+refspec`, and --mirror,
# which overwrites every remote ref.
FORCE = %r{
  (?:^|\s)--(?:force(?:-with-lease|-if-includes)?|mirror)(?:=|\s|$)
  | (?:^|\s)-[a-zA-Z]*f[a-zA-Z]*(?:\s|$)
  | (?:^|\s)\+\S
}x

# For each `git push`, check the rest of that shell command for a force flag.
# Flags may come before or after the remote.
force = command.to_enum(:scan, GIT_PUSH).any? do
  Regexp.last_match.post_match.split(SEPARATOR).first.to_s.match?(FORCE)
end
exit 0 unless force

warn "Don't force push. It rewrites history on a remote branch and detaches review comments from their commits. HCB updates feature branches by merging main into them rather than rebasing (see dev-docs/pull_requests.md). If the push was rejected, fetch and merge the remote changes and push normally; if that still fails, stop and ask the user. If the user wants a force push, they can run it themselves."
exit 2
