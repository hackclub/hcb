# frozen_string_literal: true

require "rails_helper"

RSpec.describe StripeService do
  describe ".invoice_subscription_id" do
    it "reads the subscription from invoices rendered on the current API version" do
      invoice = Stripe::Invoice.construct_from(id: "in_1234", parent: { type: "subscription_details", subscription_details: { subscription: "sub_1234" } })

      expect(described_class.invoice_subscription_id(invoice)).to eq("sub_1234")
    end

    it "falls back to the shape sent by webhook endpoints still on older API versions" do
      invoice = Stripe::Invoice.construct_from(id: "in_1234", subscription: "sub_1234")

      expect(described_class.invoice_subscription_id(invoice)).to eq("sub_1234")
    end

    it "is nil for one-off invoices in either shape" do
      expect(described_class.invoice_subscription_id(Stripe::Invoice.construct_from(id: "in_1234", parent: nil))).to be_nil
      expect(described_class.invoice_subscription_id(Stripe::Invoice.construct_from(id: "in_1234", subscription: nil))).to be_nil
    end
  end
end
