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

  describe "#active_filter_params" do
    let(:select_filter) { { key: "status", label: "Status", type: "select", options: %w[deposited canceled] } }
    let(:date_filter) { { key_base: "date", label: "Date", type: "date_range" } }
    let(:amount_filter) { { key_base: "amount", label: "Amount", type: "amount_range" } }

    it "returns the key of a plain filter that has a value" do
      expect(helper.active_filter_params(select_filter, { "status" => "deposited" })).to eq(["status"])
      expect(helper.active_filter_params(select_filter, { "status" => "" })).to eq([])
      expect(helper.active_filter_params(select_filter, {})).to eq([])
    end

    it "returns each bound of a date range that has a value" do
      expect(helper.active_filter_params(date_filter, { "date_after" => "2026-01-01" })).to eq(["date_after"])
      expect(helper.active_filter_params(date_filter, { "date_after" => "2026-01-01", "date_before" => "2026-02-01" }))
        .to eq(%w[date_after date_before])
      expect(helper.active_filter_params(date_filter, {})).to eq([])
    end

    it "returns each bound of an amount range that has a value" do
      expect(helper.active_filter_params(amount_filter, { "amount_less_than" => "100" })).to eq(["amount_less_than"])
      expect(helper.active_filter_params(amount_filter, { "amount_greater_than" => "5", "amount_less_than" => "100" }))
        .to eq(%w[amount_greater_than amount_less_than])
    end

    it "keeps check_filters? in sync" do
      expect(helper.check_filters?([select_filter, date_filter], { "date_before" => "2026-02-01" })).to be(true)
      expect(helper.check_filters?([select_filter, date_filter], {})).to be(false)
    end
  end
end
