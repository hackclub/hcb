# frozen_string_literal: true

# PreToolUse hook for Bash: block force pushes so an agent can never rewrite
# history on a remote branch. HCB updates feature branches by merging main into
# them, not rebasing, so a force push is never part of the normal workflow.
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

# A `git push` anywhere in the command (including after `;`, `&&`, `|`, or inside
# `sh -c '...'`), allowing `git -C dir push` / `git -c key=val push` forms.
GIT_PUSH = /\bgit\b(?:\s+-[cC]\s*\S+|\s+--[\w-]+(?:=\S+)?)*\s+push\b/

# Force variants: --force, --force-with-lease[=...], --force-if-includes, -f,
# combined short flags that include f (-uf, -fu), and a `+refspec`.
# A flag may be followed by whitespace, `=`, the end of the command, or a closing
# quote (e.g. `sh -c 'git push --force'`).
FORCE = %r{
  (?:^|\s)--force(?:-with-lease|-if-includes)?(?:=|\s|$|["'])
  | (?:^|\s)-[a-zA-Z]*f[a-zA-Z]*(?:\s|$|["'])
  | (?:^|\s)\+\S
}x

# Look at the text from each `git push` up to the end of the command and check
# for a force flag anywhere after it (flags may come before or after the remote).
force = command.to_enum(:scan, GIT_PUSH).any? do
  rest = Regexp.last_match.post_match
  rest.split(/(?<!\\)[;&|\n]/).first.to_s.match?(FORCE)
end
exit 0 unless force

warn "Don't force push. It rewrites history on a remote branch and detaches review comments from their commits. HCB updates feature branches by merging main into them rather than rebasing (see dev-docs/pull_requests.md). If the push was rejected, fetch and merge the remote changes and push normally; if that still fails, stop and ask the user. If the user wants a force push, they can run it themselves."
exit 2
