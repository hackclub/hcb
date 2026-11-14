# frozen_string_literal: true

require "rails_helper"

# Verifies the time limits set in config/initializers/mini_magick.rb.
RSpec.describe "MiniMagick time limits" do
  it "sets ImageMagick's own time limit" do
    expect(MiniMagick.timeout).to be_a(Integer).and be_positive
  end

  context "when coreutils' timeout is available", if: File.executable?("/usr/bin/timeout") do
    it "runs every ImageMagick command under it" do
      command = MiniMagick::Tool.new("convert").command

      expect(command.first).to eq("/usr/bin/timeout")
      expect(command).to include("convert")
    end

    it "kills a command only after ImageMagick's own limit has had a chance to fire" do
      hard_limit = Integer(MiniMagick.cli_prefix.last)

      expect(hard_limit).to be > MiniMagick.timeout
    end
  end
end
