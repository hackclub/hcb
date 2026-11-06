# frozen_string_literal: true

require "rails_helper"

RSpec.describe BreakdownEngine::MoneyFlow do
  let(:event) { create(:event, name: "Hack Night") }

  def add_transaction(code, amount_cents, date: Date.current)
    ct = create(:canonical_transaction, amount_cents:, date:)
    create(:canonical_event_mapping, event:, canonical_transaction: ct)
    ct.update_column(:hcb_code, "HCB-#{code}-#{ct.id}")
    ct
  end

  def add_card_transaction(merchant_category, amount_cents, date: Date.current)
    raw = create(:raw_stripe_transaction, amount_cents:, stripe_merchant_category: merchant_category)
    ct = create(:canonical_transaction, amount_cents:, date:, transaction_source: raw)
    create(:canonical_event_mapping, event:, canonical_transaction: ct)
    ct
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
    add_transaction("100", 1_000_00)
    add_transaction("300", -300_00)

    result = run

    expect(result[:money_in_cents]).to eq(1_000_00)
    expect(result[:money_out_cents]).to eq(300_00)
    expect(node_names(result, "hub")).to eq(["Hack Night"])
    expect(link_value(result, "Invoices", "Hack Night")).to eq(1_000.0)
    expect(link_value(result, "Hack Night", "ACH transfers")).to eq(300.0)
    expect(link_value(result, "Hack Night", "Balance")).to eq(700.0)
  end

  it "draws from the balance when spending exceeds income" do
    add_transaction("200", 100_00)
    add_transaction("310", -250_00)

    result = run

    expect(node_names(result, "balance")).to eq(["Balance"])
    expect(link_value(result, "Balance", "Hack Night")).to eq(150.0)
    expect(link_value(result, "Hack Night", "Balance")).to be_nil
  end

  it "merges codes that share a label" do
    add_transaction("200", 100_00)
    add_transaction("201", 50_00)

    expect(link_value(run, "Donations", "Hack Night")).to eq(150.0)
  end

  it "nets inflows and outflows under the same label" do
    add_transaction("100", 500_00)
    add_transaction("300", -200_00)
    add_transaction("300", 50_00)

    expect(link_value(run, "Hack Night", "ACH transfers")).to eq(150.0)
  end

  it "groups related expenses under a parent node" do
    add_transaction("100", 1_000_00)
    add_transaction("300", -200_00)
    add_transaction("310", -100_00)

    result = run

    expect(node_names(result, "group")).to eq(["Transfers"])
    expect(link_value(result, "Hack Night", "Transfers")).to eq(300.0)
    expect(link_value(result, "Transfers", "ACH transfers")).to eq(200.0)
    expect(link_value(result, "Transfers", "Wires")).to eq(100.0)
  end

  it "does not create a group for a single expense" do
    add_transaction("100", 1_000_00)
    add_transaction("700", -70_00)

    result = run

    expect(node_names(result, "group")).to be_empty
    expect(link_value(result, "Hack Night", "HCB fees")).to eq(70.0)
  end

  it "folds sources under 3% of income into Other income" do
    add_transaction("100", 1_000_00)
    add_transaction("200", 10_00)

    result = run

    expect(node_names(result, "income")).to eq(["Invoices", "Other income"])
    expect(link_value(result, "Other income", "Hack Night")).to eq(10.0)
  end

  it "labels unknown codes as Other and sorts them last" do
    add_transaction("100", 1_000_00)
    add_transaction("000", -500_00)
    add_transaction("300", -100_00)

    expenses = run[:nodes].select { |node| node[:kind] == "expense" }.map { |node| node[:name] }

    expect(expenses).to eq(["ACH transfers", "Other spending"])
  end

  it "categorizes card spending by merchant category" do
    add_transaction("100", 1_000_00)
    add_card_transaction("bakeries", -40_00)
    add_card_transaction("airlines_air_carriers", -60_00)

    result = run

    expect(link_value(result, "Hack Night", "Card spending")).to eq(100.0)
    expect(link_value(result, "Card spending", "Food")).to eq(40.0)
    expect(link_value(result, "Card spending", "Travel")).to eq(60.0)
  end

  it "only includes transactions within the date range" do
    add_transaction("100", 1_000_00, date: 2.years.ago.to_date)
    add_transaction("200", 300_00, date: 1.week.ago.to_date)

    result = run(start_date: 1.month.ago, end_date: Time.now)

    expect(result[:money_in_cents]).to eq(300_00)
    expect(node_names(result, "income")).to eq(["Donations"])
  end
end
