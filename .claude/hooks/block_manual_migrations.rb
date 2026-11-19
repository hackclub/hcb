# frozen_string_literal: true

# PreToolUse hook for Write: block creating new migration files by hand. Editing a
# migration that already exists (e.g. one a generator just created) is allowed.
#
# Claude Code sends the tool call as JSON on stdin. Run with `ruby --disable-gems`
# so it starts in a few milliseconds.
require "json"

project = File.expand_path(ENV.fetch("CLAUDE_PROJECT_DIR"))

begin
  file_path = JSON.parse($stdin.read).dig("tool_input", "file_path")
rescue JSON::ParserError => e
  warn "block-manual-migrations hook could not parse the tool input: #{e.message}"
  exit 2
end
exit 0 if file_path.nil? || file_path.empty?

# Normalize so `.`, `..`, doubled slashes, and relative paths can't slip past.
path = File.expand_path(file_path, project)

# Migrations in this checkout, or in a git worktree kept under .claude/worktrees/.
migration_dir = /\A#{Regexp.escape(project)}(?:\/\.claude\/worktrees\/[^\/]+)?\/db\/migrate\//
exit 0 unless path.match?(migration_dir)
exit 0 if File.exist?(path)

warn "Don't hand-write migration files. Generate it with a Rails generator (e.g. `bin/rails generate migration AddFooToBars foo:string` or `bin/rails generate model ...`) so it gets a correct timestamp, then edit the generated file. See https://guides.rubyonrails.org/active_record_migrations.html#generating-migration-files for more information."
exit 2
