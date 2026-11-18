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
  end
end
