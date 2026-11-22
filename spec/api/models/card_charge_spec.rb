# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::Models::CardCharge do
  let(:raw) { create(:raw_pending_stripe_transaction) }
  let(:item) { create(:ledger_item, linked_object: raw.card_charge) }
  let(:hcb_code) { create(:hcb_code, code_type: 600, ledger_item: item) }
  let(:charge) { described_class.with_details.find(hcb_code.id) }

  it "keeps the existing API public ID" do
    expect(charge.public_id).to eq(described_class.find(hcb_code.id).public_id)
    expect(charge.public_id).to start_with("chg_")
  end

  %w[pending settled reversed released declined].each do |status|
    it "uses the ledger's #{status} status without consulting legacy transactions" do
      hcb_code
      item.update!(status:)
      expect(charge).not_to receive(:pt)
      expect(charge).not_to receive(:canonical_transactions)
      expect(charge.status).to eq(status)
    end
  end

  it "reads merchant and machine-readable authorization details from the linked card charge" do
    raw.update!(stripe_transaction: raw.stripe_transaction.merge(
      "authorization_method" => "keyed_in",
      "merchant_data"        => { "name" => "Bakery", "category" => "bakeries", "country" => "US", "network_id" => "merchant_123" }
    ))

    expect(charge.merchant_data).to eq(raw.stripe_transaction["merchant_data"])
    expect(charge.authorization_method).to eq("keyed_in")
  end

  it "prefers HCB's decline reason over Stripe's" do
    raw.update!(stripe_transaction: raw.stripe_transaction.merge(
      "metadata"        => { "declined_reason" => "merchant_not_allowed" },
      "request_history" => [{ "reason" => "webhook_declined" }]
    ))

    expect(charge.decline_reason).to eq("merchant_not_allowed")
  end

  it "falls back to Stripe's decline reason" do
    raw.update!(stripe_transaction: raw.stripe_transaction.merge("request_history" => [{ "reason" => "insufficient_funds" }]))

    expect(charge.decline_reason).to eq("insufficient_funds")
  end

  it "handles a charge with no authorization or settlement details" do
    item.update!(linked_object: create(:card_charge, raw_pending_stripe_transaction: nil))

    expect(charge.merchant_data).to be_nil
    expect(charge.authorization_method).to be_nil
    expect(charge.decline_reason).to be_nil
  end

  it "preloads the new details for a collection" do
    hcb_code
    charges = described_class.with_details.where(id: hcb_code.id).to_a
    queries = []
    subscriber = ->(_name, _start, _finish, _id, payload) { queries << payload[:sql] }

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      charges.each do |record|
        record.status
        record.merchant_data
        record.authorization_method
        record.decline_reason
      end
    end

    expect(queries).to be_empty
  end
end
