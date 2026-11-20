# frozen_string_literal: true

require "spec_helper"
require "json"
require "open3"

# .claude/hooks/block_force_push.rb is a Claude Code PreToolUse hook. Claude Code
# sends it the tool call as JSON on stdin, and an exit status of 2 blocks the
# command. See .claude/settings.json for where it is registered.
RSpec.describe "block_force_push hook" do
  let(:hook) { File.expand_path("../../.claude/hooks/block_force_push.rb", __dir__) }

  def run_hook(stdin)
    _stdout, stderr, status = Open3.capture3(RbConfig.ruby, "--disable-gems", hook, stdin_data: stdin)
    [status.exitstatus, stderr]
  end

  def run_command(command)
    run_hook(JSON.generate(tool_name: "Bash", tool_input: { command: }))
  end

  blocked = [
    "git push --force",
    "git push -f",
    "git push --force-with-lease",
    "git push --force-with-lease=main origin main",
    "git push --force-if-includes origin main",
    "git push --mirror origin",
    "git push origin main --force",
    "git push origin main -f",
    "git push origin main -o -f",
    "git push -uf origin main",
    "git push -fu origin main",
    "git push origin +main",
    "git push origin +HEAD:main",
    "git push origin +refs/heads/main:refs/heads/main",
    "git -C /tmp/repo push --force",
    'git -C "my dir" push --force',
    "git -c push.default=current push -f",
    "git --no-pager push origin main --force",
    'git push "--force"',
    "git push origin main 2>&1 --force",
    "git fetch && git push --force",
    "git fetch; git push origin main -f",
    "git push origin main && git push -f",
    "sh -c 'git push --force'",
    'sh -c "git push -f"',
    "cd foo && git push -f origin HEAD",
    "git log\ngit push --force",
    # The hook only sees text, so these are blocked to stay on the safe side.
    "echo git push --force",
    "# git push --force",
  ]

  allowed = [
    "git push",
    "git push -u origin lro-agents-md",
    "git push origin main",
    "git push --set-upstream origin feature",
    "git push --dry-run",
    "git push -q -u origin branch",
    "git push origin main -o ci.skip",
    "git push origin --delete feature",
    "git push origin feature-fix",
    "git push origin main && echo --force",
    "git push origin main; rm -f file",
    "git push origin main | tee log",
    "git push origin main 2>&1",
    "git pull --force",
    "git fetch --force",
    "git commit -f",
    "git commit -m 'push things' -f",
    "rm -f foo",
    "git log --format=%s",
  ]

  blocked.each do |command|
    it "blocks #{command.inspect}" do
      status, stderr = run_command(command)

      expect(status).to eq(2)
      expect(stderr).to include("Don't force push")
    end
  end

  allowed.each do |command|
    it "allows #{command.inspect}" do
      status, stderr = run_command(command)

      expect(status).to eq(0)
      expect(stderr).to be_empty
    end
  end

  it "ignores tool calls that have no command" do
    status, = run_hook(JSON.generate(tool_name: "Write", tool_input: { file_path: "x" }))

    expect(status).to eq(0)
  end

  it "fails closed when the input is not JSON" do
    status, stderr = run_hook("nope")

    expect(status).to eq(2)
    expect(stderr).to include("could not parse")
  end
end
