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

  it "never calls Wise on USD reports and labels the rate without a currency" do
    expense = described_class.create!(report: create(:reimbursement_report), value: 33.33, memo: "Drive")
    expense.update!(value: 12.5)

    expect(expense.reload.amount_cents).to eq((12.5 * expense.rate).round)
    expect(expense.value_label).to eq("Miles (#{expense.rate}¢/mile)")
    expect(expense.card_label).to eq("Drive ($8.75)")
    expect(a_request(:post, "https://api.wise.com/v3/quotes")).not_to have_been_made
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

    it "stays approved and makes no Wise call when saved without changing the miles" do
      stub_rate(4.5)
      expense.mark_approved!
      stub_rate(9)

      expense.update!(value: "33")
      expense.save!

      expect(expense.reload).to be_approved
      expect(expense.amount_cents).to eq((33 * expense.rate * 4.5).round)
      expect(a_request(:post, "https://api.wise.com/v3/quotes")).to have_been_made.once
    end

    it "requotes in the destination currency when moved to another report" do
      stub_rate(4.5)
      expense
      stub_rate(4)

      expense.update!(report: create(:reimbursement_report, currency: "PLN"))

      expect(expense.reload.amount_cents).to eq((33 * expense.rate * 4).round)
      expect(expense.amount.currency.iso_code).to eq("PLN")
    end

    it "uses the USD rate as-is when moved to a USD report" do
      stub_rate(4.5)
      expense

      expense.update!(report: create(:reimbursement_report))

      expect(expense.reload.amount_cents).to eq(33 * expense.rate)
      expect(a_request(:post, "https://api.wise.com/v3/quotes")).to have_been_made.once
    end

    it "is zero without calling Wise when there are no miles" do
      zero = described_class.create!(report:, value: 0)
      stub_rate(4.5)
      expense.update!(value: 0)

      expect(zero.amount_cents).to eq(0)
      expect(expense.reload.amount_cents).to eq(0)
      expect(a_request(:post, "https://api.wise.com/v3/quotes")).to have_been_made.once
    end

    it "doesn't save a miles change when the exchange rate can't be fetched" do
      stub_rate(4.5)
      expense
      stub_request(:post, "https://api.wise.com/v3/quotes").to_return(status: 500)

      expect(expense.update(value: 10)).to be(false)
      expect(expense.reload).to have_attributes(value: 33, amount_cents: (33 * expense.rate * 4.5).round)
    end

    it "labels the rate as USD and the card in the report's currency" do
      stub_rate(4.5)
      expense.update!(memo: "Drive")

      expect(expense.value_label).to eq("Miles (#{expense.rate}¢ USD/mile, converted to RON)")
      expect(expense.card_label).to eq("Drive (#{Money.from_cents(10395, "RON").format})")
    end

    it "leaves standard expenses alone when the report's currency changes" do
      stub_rate(4.5)
      expense
      standard = create(:reimbursement_expense, report:, value: 10)

      report.convert_report_currency!("PLN")

      expect(standard.reload).to have_attributes(value: 10, amount_cents: 1000)
    end
  end

  it "converts into zero-decimal and three-decimal currencies" do
    stub_rate(150)
    yen = described_class.create!(report: create(:reimbursement_report, currency: "JPY"), value: 33)
    stub_rate(0.3)
    dinar = described_class.create!(report: create(:reimbursement_report, currency: "KWD"), value: 33)

    expect(yen.amount_cents).to eq(3465) # $23.10 at 150 is 3,465 yen
    expect(dinar.amount_cents).to eq(6930) # $23.10 at 0.3 is 6.930 dinar
  end

  it "is invalid when Wise answers without a usable rate" do
    stub_request(:post, "https://api.wise.com/v3/quotes")
      .to_return(status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" })

    expect(described_class.new(report: create(:reimbursement_report, currency: "RON"), value: 33)).not_to be_valid
  end

  it "fetches one exchange rate for all of a report's mileage expenses" do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    report = create(:reimbursement_report)
    expenses = Array.new(3) { described_class.create!(report:, value: 33) }
    stub_rate(4.5)

    report.convert_report_currency!("RON")

    expect(expenses.map { |expense| expense.reload.amount_cents }).to all(eq((33 * 70 * 4.5).round))
    expect(a_request(:post, "https://api.wise.com/v3/quotes")).to have_been_made.once
  end

  context "when the report moves to an organization with another mileage rate" do
    let(:report) { create(:reimbursement_report, currency: "RON") }
    let(:affiliate) { create(:event, plan_type: Event::Plan::HackClubAffiliate) }

    it "requotes at the new organization's rate" do
      stub_rate(4.5)
      expense = described_class.create!(report:, value: 33)
      stub_rate(4)

      report.update!(event: affiliate)

      expect(expense.reload.rate).to eq(35)
      expect(expense.amount_cents).to eq(33 * 35 * 4)
    end

    it "doesn't move the report when the exchange rate can't be fetched" do
      stub_rate(4.5)
      expense = described_class.create!(report:, value: 33)
      stub_request(:post, "https://api.wise.com/v3/quotes").to_return(status: 500)

      expect(report.update(event: affiliate)).to be(false)
      expect(report.errors.full_messages.to_sentence).to match(/exchange rate/i)
      expect(report.reload.event).not_to eq(affiliate)
      expect(expense.reload.amount_cents).to eq((33 * 70 * 4.5).round)
    end
  end

  it "converts the miles when a USD report switches to another currency" do
    report = create(:reimbursement_report)
    expense = described_class.create!(report:, value: 33)
    stub_rate(4.5)

    report.convert_report_currency!("RON")

    expect(expense.reload).to have_attributes(value: 33, amount_cents: (33 * expense.rate * 4.5).round)
  end
end
