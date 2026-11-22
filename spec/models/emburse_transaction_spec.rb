# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmburseTransaction, type: :model do
  let(:emburse_transaction) { create(:emburse_transaction) }

  it "is valid" do
    expect(emburse_transaction).to be_valid
  end

  describe "#memo and #transfer" do
    context "amount is negative and merchant name is null" do
      let(:emburse_transaction) { create(:emburse_transaction, amount: -100) }

      it "is a transfer back to bank account" do
        expect(emburse_transaction.memo).to eql("Transfer back to bank account")
      end

      it "is a transfer" do
        expect(emburse_transaction).to be_transfer
      end
    end

    context "amount is positive and merchant name is null" do
      let(:emburse_transaction) { create(:emburse_transaction, amount: 100, merchant_name: nil) }

      it "is a transfer from bank account" do
        expect(emburse_transaction.memo).to eql("Transfer from bank account")
      end

      it "is a transfer" do
        expect(emburse_transaction).to be_transfer
      end
    end

    context "amount is positive and merchant name is present" do
      let(:emburse_transaction) { create(:emburse_transaction, amount: 100, merchant_name: "Some merchant name") }

      it "is still a transfer from bank account" do
        expect(emburse_transaction.memo).to eql("Transfer from bank account")
      end

      it "is still a transfer" do
        expect(emburse_transaction).to be_transfer
      end
    end

    context "amount is negative and merchant name is present" do
      let(:emburse_transaction) { create(:emburse_transaction, amount: -100, merchant_name: "Some merchant name") }

      it "uses merchant name as memo" do
        expect(emburse_transaction.memo).to eql("Some merchant name")
      end

      it "is not a transfer" do
        expect(emburse_transaction).to_not be_transfer
      end
    end
  end

end
