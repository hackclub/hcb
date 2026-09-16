# frozen_string_literal: true

require "rails_helper"

RSpec.describe ComboboxHelper, type: :helper do
  describe "#combobox_tag" do
    before { allow(helper).to receive(:admin_signed_in?).and_return(false) }

    it "wires the Stimulus controller, its targets and the options endpoint" do
      html = helper.combobox_tag(:event_id, "/search")

      expect(html).to include('data-controller="combobox"')
      expect(html).to include('data-combobox-url-value="/search"')
      expect(html).to include('data-combobox-target="input"')
      expect(html).to include('data-combobox-target="hidden"')
      expect(html).to include('data-combobox-target="listbox"')
      expect(html).to include('data-combobox-target="status"')

      doc = Nokogiri::HTML.fragment(html)
      expect(doc.at_css("input[type=text]")["aria-controls"]).to eq(doc.at_css("ul")["id"])
    end

    # The submitted value lives in the hidden field; the visible input is
    # display-only and deliberately carries no `name`.
    it "submits through the hidden field only" do
      html = Nokogiri::HTML.fragment(helper.combobox_tag(:event_id, "/search"))

      expect(html.at_css("input[type=hidden]")["name"]).to eq("event_id")
      expect(html.at_css("input[type=text]")["name"]).to be_nil
    end

    # The gem generated a random id, so nothing could collide. Deriving it from
    # the field name is what makes `form.label` point at a focusable input, so
    # the derivation and the `id:` escape hatch both need to hold.
    it "derives the input id from the field name and leaves the hidden field without one" do
      html = Nokogiri::HTML.fragment(helper.combobox_tag("sponsor[event_id]", "/search"))

      expect(html.at_css("input[type=text]")["id"]).to eq("sponsor_event_id")
      expect(html.at_css("input[type=hidden]")["id"]).to be_nil
      expect(html.at_css("ul")["id"]).to eq("sponsor_event_id_listbox")
    end

    it "lets a caller override the input id where the derived one would collide" do
      html = Nokogiri::HTML.fragment(
        helper.combobox_tag(:event_id, "/search", id: "bulk_map_event_id")
      )

      expect(html.at_css("input[type=text]")["id"]).to eq("bulk_map_event_id")
      expect(html.at_css("ul")["id"]).to eq("bulk_map_event_id_listbox")
    end

    context "with a preselected record" do
      let(:event) { create(:event, name: "Hack Club HQ") }

      it "seeds the hidden field and the label from the record" do
        html = Nokogiri::HTML.fragment(helper.combobox_tag(:event_id, "/search", selected: event))
        wrapper = html.at_css("div.combobox")

        expect(wrapper["data-combobox-selected-value"]).to eq(event.id.to_s)
        expect(wrapper["data-combobox-label-value"]).to eq("Hack Club HQ")
        expect(html.at_css("input[type=hidden]")["value"]).to eq(event.id.to_s)
      end

      # The dropdown labels come from the same method, so the preselected label
      # has to agree with them or re-picking the same record changes the text.
      it "uses the admin display when an admin is signed in" do
        allow(helper).to receive(:admin_signed_in?).and_return(true)

        html = Nokogiri::HTML.fragment(helper.combobox_tag(:event_id, "/search", selected: event))

        expect(html.at_css("div.combobox")["data-combobox-label-value"])
          .to eq("Hack Club HQ (ID: #{event.id})")
      end
    end

    # Records keyed on something other than `id` (the disbursements endpoint
    # returns `public_id`) pass a Hash instead.
    it "accepts an explicit value/label Hash, with either string or symbol keys" do
      symbol_keys = Nokogiri::HTML.fragment(
        helper.combobox_tag(:event_id, "/search", selected: { value: "evt_123", label: "Hack Club HQ" })
      ).at_css("div.combobox")
      string_keys = Nokogiri::HTML.fragment(
        helper.combobox_tag(:event_id, "/search", selected: { "value" => "evt_123", "label" => "Hack Club HQ" })
      ).at_css("div.combobox")

      [symbol_keys, string_keys].each do |wrapper|
        expect(wrapper["data-combobox-selected-value"]).to eq("evt_123")
        expect(wrapper["data-combobox-label-value"]).to eq("Hack Club HQ")
      end
    end

    # The wrapper owns the width, and the listbox is sized to it, so sizing
    # classes have to land there rather than on the borderless inner input.
    it "puts caller classes on the wrapper and keeps data attributes alongside the controller" do
      html = Nokogiri::HTML.fragment(
        helper.combobox_tag(:event_id, "/search",
                            class: "!max-w-full",
                            data: { swap_organizations_target: "combobox" })
      )
      wrapper = html.at_css("div.combobox")

      expect(wrapper["class"].split).to include("combobox", "!max-w-full")
      expect(wrapper["data-swap-organizations-target"]).to eq("combobox")
      expect(wrapper["data-controller"]).to eq("combobox")
    end

    it "passes remaining options through to the visible input" do
      html = Nokogiri::HTML.fragment(
        helper.combobox_tag(:event_id, "/search", placeholder: "Select event", disabled: true)
      )
      input = html.at_css("input[type=text]")

      expect(input["placeholder"]).to eq("Select event")
      expect(input["disabled"]).to be_present
    end
  end
end
