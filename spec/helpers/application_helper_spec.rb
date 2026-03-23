# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#custom_tooltip" do
    it "renders a span with custom-tooltip class" do
      result = helper.custom_tooltip { "tooltip content" }
      expect(result).to include("<span")
      expect(result).to include("custom-tooltip")
      expect(result).to include("tooltip content")
    end

    it "adds directional class when direction is provided" do
      result = helper.custom_tooltip(:n) { "north tooltip" }
      expect(result).to include("custom-tooltip--n")
    end

    it "adds east direction class" do
      result = helper.custom_tooltip(:e) { "east tooltip" }
      expect(result).to include("custom-tooltip--e")
    end

    it "adds west direction class" do
      result = helper.custom_tooltip(:w) { "west tooltip" }
      expect(result).to include("custom-tooltip--w")
    end

    it "adds south direction class" do
      result = helper.custom_tooltip(:s) { "south tooltip" }
      expect(result).to include("custom-tooltip--s")
    end

    it "renders without directional class when direction is nil" do
      result = helper.custom_tooltip(nil) { "content" }
      expect(result).to include("custom-tooltip")
      expect(result).not_to include("custom-tooltip--")
    end

    it "renders inline content directly" do
      result = helper.custom_tooltip(:n, "<b>bold</b>".html_safe)
      expect(result).to include("<b>bold</b>")
    end

    it "prefers inline content over block when both are provided" do
      result = helper.custom_tooltip(:n, "inline content") { "block content" }
      expect(result).to include("inline content")
      expect(result).not_to include("block content")
    end
  end

  describe "#turbo_custom_tooltip" do
    it "renders a span with custom-tooltip class" do
      result = helper.turbo_custom_tooltip(:n, "frame-id", "/some/path")
      expect(result).to include("<span")
      expect(result).to include("custom-tooltip")
    end

    it "adds directional class" do
      result = helper.turbo_custom_tooltip(:n, "frame-id", "/some/path")
      expect(result).to include("custom-tooltip--n")
    end

    it "renders a turbo-frame with the given frame id and src" do
      result = helper.turbo_custom_tooltip(:n, "my-frame", "/load/path")
      expect(result).to include("turbo-frame")
      expect(result).to include("my-frame")
      expect(result).to include("/load/path")
    end

    it "sets loading to lazy on the turbo frame" do
      result = helper.turbo_custom_tooltip(:e, "frame-id", "/path")
      expect(result).to include("lazy")
    end
  end
end
