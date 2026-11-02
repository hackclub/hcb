# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventsHelper, type: :helper do
  describe "#filter_option_label" do
    # The filter dropdown and the chip that shows what you picked both resolve a
    # value through this, so they can't disagree about how a value is spelled.
    let(:transfer_type) do
      {
        key: "transfer_type",
        label: "Type",
        type: "select",
        options: [["ACH", "ach"], ["HCB transfer", "hcb_transfer"], ["PayPal", "paypal"]]
      }
    end
    let(:status) { { key: "status", label: "Status", type: "select", options: %w[deposited in_transit canceled] } }

    it "uses the label an option was declared with" do
      expect(helper.filter_option_label(transfer_type, "hcb_transfer")).to eq("HCB transfer")
      expect(helper.filter_option_label(transfer_type, "paypal")).to eq("PayPal")
    end

    it "humanizes options declared without a label" do
      expect(helper.filter_option_label(status, "in_transit")).to eq("In transit")
    end

    it "humanizes a value that isn't one of the options" do
      expect(helper.filter_option_label(transfer_type, "wire_transfer")).to eq("Wire transfer")
      expect(helper.filter_option_label({ key_base: "created", type: "date_range" }, "canceled")).to eq("Canceled")
    end
  end
end
