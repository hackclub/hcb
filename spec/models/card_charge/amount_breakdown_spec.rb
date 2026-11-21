# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardCharge::AmountBreakdown, type: :model do
  def authorization(amount_cents:, merchant_amount: amount_cents, merchant_currency: "usd", approved: true)
    create(:raw_pending_stripe_transaction, stripe_transaction_id: "iauth_breakdown", amount_cents: -amount_cents).tap do |rpst|
      rpst.update!(stripe_transaction: rpst.stripe_transaction.merge(
        "approved"          => approved,
        "created"           => 1.day.ago.to_i,
        "merchant_amount"   => merchant_amount,
        "merchant_currency" => merchant_currency,
        "request_history"   => [{ "approved" => approved, "amount" => amount_cents, "merchant_amount" => merchant_amount, "merchant_currency" => merchant_currency }]
      ))
    end
  end

  def settlement(type:, amount_cents:, merchant_amount:, merchant_currency: "usd", created: Time.current)
    sign = type == "refund" ? 1 : -1
    create(:raw_stripe_transaction, stripe_authorization_id: "iauth_breakdown", amount_cents: sign * amount_cents).tap do |rst|
      rst.update!(stripe_transaction: rst.stripe_transaction.merge(
        "type"              => type,
        "amount"            => sign * amount_cents,
        "merchant_amount"   => sign * merchant_amount,
        "merchant_currency" => merchant_currency,
        "created"           => created.to_i
      ))
    end
  end

  def breakdown_for(rpst) = rpst.card_charge.reload.amount_breakdown

  it "itemizes a plain USD charge" do
    rpst = authorization(amount_cents: 1_000)
    settlement(type: "capture", amount_cents: 1_000, merchant_amount: 1_000)

    breakdown = breakdown_for(rpst)
    expect(breakdown.entries.map(&:label)).to eq(["Authorized", "Charged"])
    expect(breakdown.charged_amount).to eq(Money.new(1_000, "USD"))
    expect(breakdown).not_to be_foreign_currency
  end

  it "itemizes a foreign-currency charge and its partial refund" do
    rpst = authorization(amount_cents: 1_100, merchant_amount: 1_000, merchant_currency: "eur")
    settlement(type: "capture", amount_cents: 1_100, merchant_amount: 1_000, merchant_currency: "eur", created: 12.hours.ago)
    settlement(type: "refund", amount_cents: 540, merchant_amount: 500, merchant_currency: "eur")

    breakdown = breakdown_for(rpst)

    expect(breakdown.entries.map(&:kind)).to eq([:authorization, :capture, :refund])
    expect(breakdown.entries.map(&:amount)).to eq([Money.new(1_100, "USD"), Money.new(1_100, "USD"), Money.new(540, "USD")])

    refund = breakdown.refunds.sole
    expect(refund.merchant_amount).to eq(Money.new(500, "EUR"))
    expect(refund).to be_foreign_currency
    expect(breakdown.refunded_amount).to eq(Money.new(540, "USD"))
    expect(breakdown.charged_amount).to eq(Money.new(1_100, "USD"))
  end

  it "handles zero-decimal currencies" do
    rpst = authorization(amount_cents: 700, merchant_amount: 1_000, merchant_currency: "jpy")

    expect(breakdown_for(rpst).entries.sole.merchant_amount.format).to eq("¥1,000")
  end

  it "labels a declined authorization" do
    rpst = authorization(amount_cents: 700, merchant_amount: 600, merchant_currency: "gbp", approved: false)

    breakdown = breakdown_for(rpst)
    expect(breakdown.entries.sole.label).to eq("Declined")
    expect(breakdown.charged_amount).to be_nil
  end
end
