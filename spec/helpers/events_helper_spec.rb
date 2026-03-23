# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventsHelper, type: :helper do
  describe "#event_logo_for" do
    it "returns nil when event is nil" do
      expect(helper.event_logo_for(nil)).to be_nil
    end

    it "returns nil when event has no logo attached" do
      event = create(:event)
      expect(helper.event_logo_for(event)).to be_nil
    end

    it "returns a URL when a non-variable logo is attached" do
      event = create(:event)
      logo_path = Rails.root.join("app/assets/images/logo-production.png")
      event.logo.attach(io: File.open(logo_path), filename: "logo.png", content_type: "image/png")
      result = helper.event_logo_for(event)
      expect(result).to be_a(String)
      expect(result).not_to be_empty
    end
  end

  describe "#event_mention" do
    context "when event is nil" do
      it "renders a span (not a link) with default name" do
        result = helper.event_mention(nil)
        expect(result).to include("<span")
        expect(result).not_to include("<a ")
        expect(result).to include("No Event")
      end

      it "uses a custom default_name when provided" do
        result = helper.event_mention(nil, default_name: "Unknown Org")
        expect(result).to include("Unknown Org")
      end

      it "does not render a tooltip when event is nil" do
        result = helper.event_mention(nil)
        expect(result).not_to include("turbo-frame")
      end

      it "uses custom aria_label when provided" do
        result = helper.event_mention(nil, aria_label: "Custom label")
        expect(result).to include('aria-label="Custom label"')
      end

      it "sets default aria_label for nil event" do
        result = helper.event_mention(nil)
        expect(result).to include('aria-label="No event found"')
      end
    end

    context "when event is present" do
      let(:event) { create(:event, name: "Test Org") }

      it "renders a link to the event" do
        result = helper.event_mention(event)
        expect(result).to include("<a ")
        expect(result).to include(event_path(event))
      end

      it "includes the event name" do
        result = helper.event_mention(event)
        expect(result).to include("Test Org")
      end

      it "includes the mention CSS class" do
        result = helper.event_mention(event)
        expect(result).to include("mention")
      end

      it "includes a turbo frame tooltip by default" do
        result = helper.event_mention(event)
        expect(result).to include("turbo-frame")
        expect(result).to include(event_async_card_path(event))
      end

      it "does not include tooltip when disable_tooltip: true" do
        result = helper.event_mention(event, disable_tooltip: true)
        expect(result).not_to include("turbo-frame")
      end

      it "uses the event name as aria_label by default" do
        result = helper.event_mention(event)
        expect(result).to include('aria-label="Test Org"')
      end

      it "uses custom aria_label when provided" do
        result = helper.event_mention(event, aria_label: "Override label")
        expect(result).to include('aria-label="Override label"')
      end

      it "adds badge classes when comment_mention: true" do
        result = helper.event_mention(event, comment_mention: true)
        expect(result).to include("badge")
        expect(result).to include("bg-muted")
        expect(result).to include("ml0")
      end

      it "does not duplicate classes" do
        result = helper.event_mention(event, comment_mention: true)
        classes = result.match(/class="([^"]+)"/)[1].split
        expect(classes.uniq.length).to eq(classes.length)
      end

      it "hides avatar when hide_avatar: true" do
        result_with = helper.event_mention(event, hide_avatar: false)
        result_without = helper.event_mention(event, hide_avatar: true)
        # With avatar, should have more content (img or svg)
        expect(result_without).not_to include("<img")
      end

      it "merges extra CSS classes" do
        result = helper.event_mention(event, class: "extra-class")
        expect(result).to include("extra-class")
        expect(result).to include("mention")
      end
    end
  end

  describe "#event_avatar_for" do
    context "when event has no logo" do
      it "returns an inline SVG icon for nil event" do
        result = helper.event_avatar_for(nil)
        expect(result).to include("<svg").or include("people-2")
      end

      it "returns an inline SVG icon for event without logo" do
        event = create(:event)
        result = helper.event_avatar_for(event)
        expect(result).to include("<svg").or include("people-2")
      end
    end

    context "when event has a logo" do
      let(:event) { create(:event) }

      before do
        logo_path = Rails.root.join("app/assets/images/logo-production.png")
        event.logo.attach(io: File.open(logo_path), filename: "logo.png", content_type: "image/png")
      end

      it "returns an image tag" do
        result = helper.event_avatar_for(event)
        expect(result).to include("<img")
      end

      it "includes rounded and shrink-none classes" do
        result = helper.event_avatar_for(event)
        expect(result).to include("rounded")
        expect(result).to include("shrink-none")
      end

      it "uses the specified size" do
        result = helper.event_avatar_for(event, size: 48)
        expect(result).to include('width="48"')
        expect(result).to include('height="48"')
      end

      it "uses default size of 24" do
        result = helper.event_avatar_for(event)
        expect(result).to include('width="24"')
        expect(result).to include('height="24"')
      end

      it "uses event name as alt text" do
        result = helper.event_avatar_for(event)
        expect(result).to include("alt=\"#{event.name}\"")
      end

      it "uses custom alt text when provided" do
        result = helper.event_avatar_for(event, alt: "Custom alt")
        expect(result).to include('alt="Custom alt"')
      end

      it "includes data-behavior=mention when click_to_mention is true" do
        result = helper.event_avatar_for(event, click_to_mention: true)
        expect(result).to include("mention")
        expect(result).to include(event_path(event))
      end

      it "does not include mention behavior when click_to_mention is false" do
        result = helper.event_avatar_for(event, click_to_mention: false)
        expect(result).not_to include("data-behavior")
      end

      it "merges custom class with default classes" do
        result = helper.event_avatar_for(event, class: "custom-class")
        expect(result).to include("custom-class")
        expect(result).to include("rounded")
      end
    end
  end
end
