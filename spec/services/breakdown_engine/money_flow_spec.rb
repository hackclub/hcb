# frozen_string_literal: true

require "rails_helper"

RSpec.describe BreakdownEngine::MoneyFlow do
  let(:event) { create(:event, name: "Hack Night") }

  def add_item(linked_object_type, amount_cents, date: Date.current, linked_object_id: nil)
    item = create(:ledger_item)
    Ledger::Mapping.create!(ledger: event.ledger, ledger_item: item, on_primary_ledger: true)
    item.update_columns(amount_cents:, datetime: date.in_time_zone, linked_object_type:, linked_object_id:, ct_count: 1)
    item
  end

  def add_card_charge(merchant_category, amount_cents, date: Date.current)
    add_item("CardCharge", amount_cents, date:, linked_object_id: CardCharge.create!(merchant_category:).id)
  end

  def run(**options)
    described_class.new(event, **options).run
  end

  def node_names(result, kind)
    result[:nodes].select { |node| node[:kind] == kind }.map { |node| node[:name] }
  end

  def link_value(result, from, to)
    source = result[:nodes].index { |node| node[:name] == from }
    target = result[:nodes].index { |node| node[:name] == to }
    result[:links].find { |link| link[:source] == source && link[:target] == target }&.dig(:value)
  end

  it "returns an empty graph when there are no transactions" do
    expect(run).to eq(nodes: [], links: [], money_in_cents: 0, money_out_cents: 0)
  end

  it "routes income through the event to expenses and the remaining balance" do
    add_item("Invoice", 1_000_00)
    add_item("AchTransfer", -300_00)

    result = run

    expect(result[:money_in_cents]).to eq(1_000_00)
    expect(result[:money_out_cents]).to eq(300_00)
    expect(node_names(result, "hub")).to eq(["Hack Night"])
    expect(link_value(result, "Invoices", "Hack Night")).to eq(1_000.0)
    expect(link_value(result, "Hack Night", "ACH transfers")).to eq(300.0)
    expect(link_value(result, "Hack Night", "Balance")).to eq(700.0)
  end

  it "draws from the balance when spending exceeds income" do
    add_item("Donation", 100_00)
    add_item("Wire", -250_00)

    result = run

    expect(node_names(result, "balance")).to eq(["Balance"])
    expect(link_value(result, "Balance", "Hack Night")).to eq(150.0)
    expect(link_value(result, "Hack Night", "Balance")).to be_nil
  end

  it "merges types that share a label" do
    add_item("Check", 100_00)
    add_item("IncreaseCheck", 50_00)

    expect(link_value(run, "Checks", "Hack Night")).to eq(150.0)
  end

  it "nets inflows and outflows under the same label" do
    add_item("Invoice", 500_00)
    add_item("AchTransfer", -200_00)
    add_item("AchTransfer", 50_00)

    expect(link_value(run, "Hack Night", "ACH transfers")).to eq(150.0)
  end

  it "totals money in and out by ledger item, like the ledger page" do
    add_item("Invoice", 1_000_00)
    add_item("BankFee", -70_00)
    add_item("FeeReimbursementGroup", 20_00)

    result = run

    expect(result[:money_in_cents]).to eq(1_020_00)
    expect(result[:money_out_cents]).to eq(70_00)
    expect(link_value(result, "Hack Night", "HCB fees")).to eq(50.0)
  end

  it "groups related expenses under a parent node" do
    add_item("Invoice", 1_000_00)
    add_item("AchTransfer", -200_00)
    add_item("Wire", -100_00)

    result = run

    expect(node_names(result, "group")).to eq(["Transfers"])
    expect(link_value(result, "Hack Night", "Transfers")).to eq(300.0)
    expect(link_value(result, "Transfers", "ACH transfers")).to eq(200.0)
    expect(link_value(result, "Transfers", "Wires")).to eq(100.0)
  end

  it "does not create a group for a single expense" do
    add_item("Invoice", 1_000_00)
    add_item("BankFee", -70_00)

    result = run

    expect(node_names(result, "group")).to be_empty
    expect(link_value(result, "Hack Night", "HCB fees")).to eq(70.0)
  end

  it "folds sources under 3% of income into Other income" do
    add_item("Invoice", 1_000_00)
    add_item("Donation", 10_00)

    result = run

    expect(node_names(result, "income")).to eq(["Invoices", "Other income"])
    expect(link_value(result, "Other income", "Hack Night")).to eq(10.0)
  end

  it "labels items without a linked object as Other and sorts them last" do
    add_item("Invoice", 1_000_00)
    add_item(nil, -500_00)
    add_item("AchTransfer", -100_00)

    expenses = run[:nodes].select { |node| node[:kind] == "expense" }.map { |node| node[:name] }

    expect(expenses).to eq(["ACH transfers", "Other spending"])
  end

  it "categorizes card spending by merchant category" do
    add_item("Invoice", 1_000_00)
    add_card_charge("bakeries", -40_00)
    add_card_charge("airlines_air_carriers", -60_00)

    result = run

    expect(link_value(result, "Hack Night", "Card spending")).to eq(100.0)
    expect(link_value(result, "Card spending", "Food")).to eq(40.0)
    expect(link_value(result, "Card spending", "Travel")).to eq(60.0)
  end

  it "only includes transactions within the date range" do
    add_item("Invoice", 1_000_00, date: 2.years.ago.to_date)
    add_item("Donation", 300_00, date: 1.week.ago.to_date)

    result = run(start_date: 1.month.ago, end_date: Time.now)

    expect(result[:money_in_cents]).to eq(300_00)
    expect(node_names(result, "income")).to eq(["Donations"])
  end
end
