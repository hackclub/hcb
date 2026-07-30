# frozen_string_literal: true

require "rails_helper"

RSpec.describe PopoverHelper, type: :helper do
  describe "#admin_process_popover_data" do
    before { allow(helper).to receive(:admin_popovers_enabled?).and_return(true) }

    # One row per transfer type the admin tables can open in the popover. Built,
    # not created, so this doesn't need a factory for each model.
    usd = { amount: 12_345 }
    with_currency = { amount_cents: 12_345, currency: "USD" }

    [
      [AchTransfer, "ACH transfer", "ach_transfer_process_7", "ach_start_approval", usd],
      [Wire, "Wire", "wire_process_7", "wire_process", with_currency],
      [WiseTransfer, "Wise transfer", "wise_transfer_process_7", "wise_transfer_process", with_currency],
      [PaypalTransfer, "PayPal transfer", "paypal_transfer_process_7", "paypal_transfer_process", { amount_cents: 12_345 }],
      [IncreaseCheck, "Check", "increase_check_process_7", "increase_check_process", usd],
      [Disbursement, "Transfer", "disbursement_process_7", "disbursement_process", usd],
    ].each do |klass, label, frame_id, route_segment, attrs|
      it "points the popover at #{klass.name}'s process screen" do
        data = helper.admin_process_popover_data(klass.new(id: 7, **attrs))

        expect(data[:modal]).to eq("shared_popover")
        expect(data[:behavior]).to eq("modal_trigger")
        expect(data[:popover_frame_id]).to eq(frame_id)
        expect(data[:popover_src]).to include(route_segment)
        # The frame src, the pushed URL and the pop-out link are all the same
        # screen — the popover just renders it without the admin layout.
        expect(data[:popover_state_url]).to eq(data[:popover_src])
        expect(data[:popover_external_link]).to eq(data[:popover_src])
        expect(data[:popover_title]).to start_with("#{label} #7 · ")
      end
    end

    it "returns nothing for a record with no process screen" do
      expect(helper.admin_process_popover_data(Event.new(id: 1))).to eq({})
    end

    it "returns nothing when the viewer isn't an admin" do
      allow(helper).to receive(:admin_popovers_enabled?).and_return(false)

      expect(helper.admin_process_popover_data(AchTransfer.new(id: 7, amount: 1))).to eq({})
    end
  end
end
