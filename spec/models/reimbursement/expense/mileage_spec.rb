# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reimbursement::Expense::Mileage, type: :model do
  def stub_rate(rate)
    stub_request(:post, "https://api.wise.com/v3/quotes")
      .to_return(status: 200, body: { rate: }.to_json, headers: { "Content-Type" => "application/json" })
  end

  it "uses the USD rate as-is on USD reports" do
    expense = described_class.create!(report: create(:reimbursement_report), value: 33)

    expect(expense.amount_cents).to eq(33 * expense.rate)
  end

  context "on a non-USD report" do
    let(:report) { create(:reimbursement_report, currency: "RON") }
    let(:expense) { described_class.create!(report:, value: 33) }

    it "converts the USD rate into the report's currency" do
      stub_rate(4.5)

      expect(expense.amount_cents).to eq((33 * expense.rate * 4.5).round)
    end

    it "doesn't requote when the miles are unchanged" do
      stub_rate(4.5)
      expense
      stub_rate(9)

      expect { expense.update!(memo: "Drive") }.not_to(change { expense.reload.amount_cents })
    end

    it "is invalid when the exchange rate can't be fetched" do
      stub_request(:post, "https://api.wise.com/v3/quotes").to_return(status: 500)

      expect(described_class.new(report:, value: 33)).not_to be_valid
    end

    it "requotes when the report's currency changes" do
      stub_rate(4.5)
      expense
      stub_rate(4)

      report.convert_report_currency!("PLN")

      expect(expense.reload).to have_attributes(value: 33, amount_cents: (33 * expense.rate * 4).round)
    end

    it "requotes when the miles change" do
      stub_rate(4.5)
      expense
      stub_rate(4)

      expense.update!(value: 10)

      expect(expense.reload.amount_cents).to eq((10 * expense.rate * 4).round)
    end

    it "uses the USD rate as-is when the report switches back to USD" do
      stub_rate(4.5)
      expense

      report.convert_report_currency!("USD")

      expect(expense.reload).to have_attributes(value: 33, amount_cents: 33 * expense.rate)
      expect(a_request(:post, "https://api.wise.com/v3/quotes")).to have_been_made.once
    end

    it "rolls back the currency change when the requote fails" do
      stub_rate(4.5)
      expense
      stub_request(:post, "https://api.wise.com/v3/quotes").to_return(status: 500)

      expect { report.convert_report_currency!("PLN") }.to raise_error(ActiveRecord::RecordInvalid)

      expect(report.reload.currency).to eq("RON")
      expect(expense.reload.amount_cents).to eq((33 * expense.rate * 4.5).round)
    end

    it "leaves an approved expense on a closed report untouched when the currency changes" do
      stub_rate(4.5)
      expense.mark_approved!
      report.update_columns(aasm_state: "reimbursed")
      stub_rate(4)

      report.convert_report_currency!("PLN")

      expect(expense.reload).to be_approved
      expect(expense.amount_cents).to eq((33 * expense.rate * 4.5).round)
    end
  end
end
