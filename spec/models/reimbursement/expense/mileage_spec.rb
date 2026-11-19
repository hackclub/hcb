# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reimbursement::Expense::Mileage, type: :model do
  let(:event) { create(:event) }
  let(:user) { create(:user) }

  def create_mileage(report, miles)
    report.expenses.create!(type: described_class.name, value: miles, memo: "Drive", category: "Mileage")
  end

  describe "#set_amount_cents" do
    it "charges the mileage rate in US cents on a USD report" do
      report = create(:reimbursement_report, user:, event:, currency: "USD")

      expense = create_mileage(report, 100)

      expect(expense.rate).to eq(70)
      expect(expense.amount_cents).to eq(70_00)
    end

    it "converts the USD mileage total into the report's currency" do
      report = create(:reimbursement_report, user:, event:, currency: "GBP")

      expense = create_mileage(report, 100)

      # $70.00 at the fixture ECB rates (EUR→USD 1.1756, EUR→GBP 0.87310)
      expect(expense.amount_cents).to eq(51_99)
      expect(expense.amount).to eq(Money.from_cents(51_99, "GBP"))
      expect(expense.value_label).to eq("Miles (70¢ USD/mile)")
    end

    it "recalculates when the miles change" do
      report = create(:reimbursement_report, user:, event:, currency: "GBP")
      expense = create_mileage(report, 100)

      expense.update!(value: 200)

      expect(expense.amount_cents).to eq(103_98)
    end

    it "leaves the amount alone when a save doesn't touch the miles" do
      report = create(:reimbursement_report, user:, event:, currency: "GBP")
      expense = create_mileage(report, 100)
      allow(MoneyService).to receive(:convert_from_usd).and_call_original

      expense.update!(memo: "Drive to the venue")
      expense.mark_approved!

      expect(MoneyService).not_to have_received(:convert_from_usd)
      expect(expense.reload.amount_cents).to eq(51_99)
      expect(expense).to be_approved
    end

    it "doesn't look up an exchange rate for an empty expense" do
      report = create(:reimbursement_report, user:, event:, currency: "GBP")
      allow(MoneyService).to receive(:convert_from_usd).and_call_original

      expense = report.expenses.create!(type: described_class.name, category: "Mileage")

      expect(expense.amount_cents).to eq(0)
      expect(MoneyService).not_to have_received(:convert_from_usd)
    end
  end

  describe "Reimbursement::Report#convert_report_currency!" do
    it "keeps the miles and recomputes the amount in the new currency" do
      report = create(:reimbursement_report, user:, event:, currency: "USD")
      expense = create_mileage(report, 100)
      expect(expense.amount_cents).to eq(70_00)

      report.convert_report_currency!("GBP")

      expense.reload
      expect(expense.value).to eq(100)
      expect(expense.amount_cents).to eq(51_99)
      expect(expense.currency).to eq("GBP")
    end
  end
end
