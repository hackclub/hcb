# frozen_string_literal: true

require "rails_helper"

RSpec.describe PopoverHelper, type: :helper do
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
