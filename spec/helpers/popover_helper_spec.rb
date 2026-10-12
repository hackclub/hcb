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
      [Invoice, "Invoice", "invoice_process_7", "invoice_process", { item_amount: 12_345 }],
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

    it "names the organization as a subtitle, keeping the title short" do
      event = build_stubbed(:event, name: "ExpensiCon 2023 (Non-Transparent Event)")
      transfer = AchTransfer.new(id: 7, amount: 12_345)
      allow(transfer).to receive(:event).and_return(event)

      data = helper.admin_process_popover_data(transfer)

      expect(data[:popover_title]).to eq("ACH transfer #7 · $123.45")
      expect(data[:popover_subtitle]).to eq("ExpensiCon 2023 (Non-Transparent Event)")
    end

    it "returns nothing for a record with no process screen" do
      expect(helper.admin_process_popover_data(Event.new(id: 1))).to eq({})
    end

    it "returns nothing when the viewer isn't an admin" do
      allow(helper).to receive(:admin_popovers_enabled?).and_return(false)

      expect(helper.admin_process_popover_data(AchTransfer.new(id: 7, amount: 1))).to eq({})
    end
  end

  describe "#admin_popover_data_for" do
    before { allow(helper).to receive(:admin_popovers_enabled?).and_return(true) }

    it "adds the organization without touching the user-facing title" do
      event = build_stubbed(:event, name: "ExpensiCon 2023")
      hcb_code = HcbCode.new(hcb_code: "HCB-100-1")
      allow(helper).to receive(:hcb_code_popover_data).with(hcb_code)
                                                      .and_return({ popover_title: "Donation of $5.00" })
      allow(hcb_code).to receive(:event).and_return(event)

      data = helper.admin_popover_data_for(hcb_code)

      expect(data[:popover_title]).to eq("Donation of $5.00")
      expect(data[:popover_subtitle]).to eq("ExpensiCon 2023")
    end

    it "omits the subtitle for records with no organization" do
      legal_entity = LegalEntity.new(id: 3)
      allow(helper).to receive(:legal_entity_popover_data).with(legal_entity)
                                                          .and_return({ popover_title: "Payment information for Orpheus" })

      data = helper.admin_popover_data_for(legal_entity)

      expect(data[:popover_title]).to eq("Payment information for Orpheus")
      expect(data).not_to have_key(:popover_subtitle)
    end
  end
end
