# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReactOnRailsMigrationHelper, type: :helper do
  describe "#react_on_rails_component" do
    let(:view_proxy) { instance_double(ReactOnRailsMigrationHelper::ViewProxy, react_component: "mount") }

    before do
      allow(ReactOnRailsMigrationHelper::ViewProxy).to receive(:new).with(helper).and_return(view_proxy)
    end

    it "keeps the explicit React on Rails props/html_options call shape" do
      helper.react_on_rails_component(
        "BookkeepingStripeChargeLookup",
        props: { stripe_charge_id: "ch_123" },
        html_options: { class: "lookup" },
        prerender: true,
      )

      expect(view_proxy).to have_received(:react_component).with(
        "BookkeepingStripeChargeLookup",
        props: { stripe_charge_id: "ch_123" },
        prerender: true,
        html_options: { class: "lookup" },
      )
    end

    it "accepts react-rails-style positional props and html options" do
      helper.react_on_rails_component(
        "BookkeepingStripeChargeLookup",
        { stripe_charge_id: "ch_123" },
        { tag: :span, class: "lookup" },
      )

      expect(view_proxy).to have_received(:react_component).with(
        "BookkeepingStripeChargeLookup",
        props: { stripe_charge_id: "ch_123" },
        prerender: false,
        html_options: { tag: :span, class: "lookup" },
      )
    end

    it "accepts implicit keyword props for mechanical legacy-call migration" do
      helper.react_on_rails_component("BookkeepingStripeChargeLookup", stripe_charge_id: "ch_123")

      expect(view_proxy).to have_received(:react_component).with(
        "BookkeepingStripeChargeLookup",
        props: { stripe_charge_id: "ch_123" },
        prerender: false,
        html_options: {},
      )
    end
  end
end
