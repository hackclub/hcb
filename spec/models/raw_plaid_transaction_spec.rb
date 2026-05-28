# frozen_string_literal: true

require "rails_helper"

RSpec.describe RawPlaidTransaction, type: :model do
  it "is valid" do
    raw_plaid_transaction = create(:raw_plaid_transaction)
    expect(raw_plaid_transaction).to be_valid
  end

  describe "#amount" do
    it "uses money gem to display amount" do
      raw_plaid_transaction = create(:raw_plaid_transaction, amount_cents: 100)

      expect(raw_plaid_transaction.amount).to eql(Money.new(100))
    end
  end
end
