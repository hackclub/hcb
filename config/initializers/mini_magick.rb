# frozen_string_literal: true

# Bound how long a single ImageMagick command can run, so one slow or stuck
# image can't hold a web or job worker indefinitely.
#
# `config.timeout` sets ImageMagick's own time limit (MAGICK_TIME_LIMIT), which
# fails cleanly with MiniMagick::TimeoutError. ImageMagick only checks that limit
# between its own processing steps, so it can't stop a command that is stuck
# inside a decoder library. Where coreutils' `timeout` is available (it isn't on
# macOS by default), every command also runs under it: SIGTERM a few seconds
# after ImageMagick's own limit, then SIGKILL if the process is still alive.
MiniMagick.configure do |config|
  time_limit = 30 # seconds

  config.timeout = time_limit

  timeout_executable = "/usr/bin/timeout"
  if File.executable?(timeout_executable)
    config.cli_prefix = [timeout_executable, "--kill-after=5", (time_limit + 5).to_s]
  end
end
