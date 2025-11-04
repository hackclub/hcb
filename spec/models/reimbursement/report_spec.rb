# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reimbursement::Report, type: :model do
  describe "mark_draft event" do
    context "when transitioning from reimbursement_approved to draft" do
      it "deletes Wise fee expenses" do
        # Set up user with payout method
        user = create(
          :user,
          full_name: "Test User",
          email: "test@example.com",
          payout_method: User::PayoutMethod::WiseTransfer.new(
            address_line1: "123 Main St",
            address_city: "Test City",
            address_state: "TS",
            recipient_country: "US",
            address_postal_code: "12345",
            currency: "USD",
          )
        )
        event = create(:event, name: "Test Event")

        # Create a report
        report = Reimbursement::Report.create!(
          name: "Test Report",
          user:,
          event:,
          currency: "USD",
          aasm_state: :reimbursement_approved
        )

        # Create a regular expense
        expense = report.expenses.create!(
          value: 100.00,
          memo: "Regular expense",
          aasm_state: :approved
        )

        # Create a Wise fee expense
        fee_expense = report.expenses.create!(
          value: 10.00,
          memo: Reimbursement::Report::WISE_TRANSFER_FEE_MEMO,
          type: Reimbursement::Expense::Fee,
          aasm_state: :approved
        )

        # Verify both expenses exist
        expect(report.expenses.count).to eq(2)
        expect(report.expenses.where(type: Reimbursement::Expense::Fee.name).count).to eq(1)

        # Mark the report as draft
        report.mark_draft!

        # Verify the Wise fee expense was deleted
        expect(report.expenses.count).to eq(1)
        expect(report.expenses.where(type: Reimbursement::Expense::Fee.name).count).to eq(0)
        expect(report.expenses.first.id).to eq(expense.id)
        expect(report.draft?).to be true
      end

      it "does not delete non-Wise fee expenses" do
        user = create(
          :user,
          full_name: "Test User",
          email: "test@example.com",
          payout_method: User::PayoutMethod::WiseTransfer.new(
            address_line1: "123 Main St",
            address_city: "Test City",
            address_state: "TS",
            recipient_country: "US",
            address_postal_code: "12345",
            currency: "USD",
          )
        )
        event = create(:event, name: "Test Event")

        report = Reimbursement::Report.create!(
          name: "Test Report",
          user:,
          event:,
          currency: "USD",
          aasm_state: :reimbursement_approved
        )

        # Create regular expenses
        expense1 = report.expenses.create!(value: 100.00, memo: "Regular expense", aasm_state: :approved)
        expense2 = report.expenses.create!(value: 50.00, memo: "Another expense", aasm_state: :approved)

        # Verify expenses exist
        expect(report.expenses.count).to eq(2)

        # Mark the report as draft
        report.mark_draft!

        # Verify all expenses still exist
        expect(report.expenses.count).to eq(2)
        expect(report.draft?).to be true
      end
    end

    context "when transitioning from other states to draft" do
      it "deletes Wise fee expenses when transitioning from submitted" do
        user = create(
          :user,
          full_name: "Test User",
          email: "test@example.com",
          payout_method: User::PayoutMethod::WiseTransfer.new(
            address_line1: "123 Main St",
            address_city: "Test City",
            address_state: "TS",
            recipient_country: "US",
            address_postal_code: "12345",
            currency: "USD",
          )
        )
        event = create(:event, name: "Test Event")

        report = Reimbursement::Report.create!(
          name: "Test Report",
          user:,
          event:,
          currency: "USD",
          aasm_state: :submitted
        )

        # Create a Wise fee expense (edge case)
        fee_expense = report.expenses.create!(
          value: 10.00,
          memo: Reimbursement::Report::WISE_TRANSFER_FEE_MEMO,
          type: Reimbursement::Expense::Fee,
          aasm_state: :approved
        )

        expect(report.expenses.count).to eq(1)

        # Mark the report as draft
        report.mark_draft!

        # Verify the Wise fee expense was deleted
        expect(report.expenses.count).to eq(0)
        expect(report.draft?).to be true
      end
    end
  end
end
