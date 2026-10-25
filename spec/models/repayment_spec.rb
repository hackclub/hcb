# frozen_string_literal: true

require "rails_helper"

RSpec.describe Repayment do
  let(:destination_event) { create(:event) }
  let(:expense) { create(:canonical_transaction, event: destination_event, amount_cents: -100_00) }
  let(:other_expense) { create(:canonical_transaction, event: destination_event, amount_cents: -25_00) }
  let(:disbursement) { create(:disbursement, event: destination_event, amount: 125_00, transfer_type: "repayment") }

  describe "repaying in full" do
    it "only has to match the repaid transaction, not the whole transfer" do
      repayment = disbursement.repayments.build(repaid_ledger_item: expense.ledger_item, amount_cents: 100_00)

      expect(repayment).to be_valid
    end

    it "can't cover part of the repaid transaction" do
      repayment = disbursement.repayments.build(repaid_ledger_item: expense.ledger_item, amount_cents: 50_00)

      expect(repayment).not_to be_valid
      expect(repayment.errors[:amount_cents]).to include("must match the full amount of the repaid transaction")
    end
  end

  describe "on the disbursement" do
    it "is valid when the repayments add up to the transfer's amount" do
      disbursement.repayments.create!(repaid_ledger_item: expense.ledger_item, amount_cents: 100_00)
      disbursement.repayments.create!(repaid_ledger_item: other_expense.ledger_item, amount_cents: 25_00)

      expect(disbursement.reload).to be_valid
    end

    it "is invalid when the repayments don't add up to the transfer's amount" do
      disbursement.repayments.create!(repaid_ledger_item: expense.ledger_item, amount_cents: 100_00)

      expect(disbursement.reload).not_to be_valid
      expect(disbursement.errors[:amount]).to include("must equal the total of the repaid transactions")
    end

    it "isn't checked before any repayments exist" do
      expect(disbursement).to be_valid
    end

    it "isn't checked for plain transfers" do
      transfer = create(:disbursement, event: destination_event, amount: 1_00, transfer_type: "transfer")
      described_class.new(disbursement: transfer, repaid_ledger_item: expense.ledger_item, amount_cents: 100_00).save!(validate: false)

      expect(transfer.reload).to be_valid
    end
  end
end
