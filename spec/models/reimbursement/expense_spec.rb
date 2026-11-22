# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reimbursement::Expense do
  describe "transaction_category_slug" do
    it "accepts any transaction category" do
      expect(build(:reimbursement_expense, transaction_category_slug: "server-hosting")).to be_valid
    end

    it "rejects a slug that isn't a transaction category" do
      expense = build(:reimbursement_expense, transaction_category_slug: "snacks")

      expect(expense).not_to be_valid
      expect(expense.errors[:transaction_category_slug]).to be_present
    end

    it "can be blank" do
      expect(build(:reimbursement_expense, transaction_category_slug: nil)).to be_valid
    end

    it "sends an approved expense back to pending when it changes" do
      expense = create(:reimbursement_expense, memo: "Hotel", transaction_category_slug: "travel")
      expense.update_column(:aasm_state, "approved")

      expense.update!(transaction_category_slug: "food-fun")

      expect(expense).to be_pending
    end
  end
end
