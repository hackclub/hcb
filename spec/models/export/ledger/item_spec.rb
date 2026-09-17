# frozen_string_literal: true

require "rails_helper"

RSpec.describe Export::Ledger::Item do
  let(:event) { create(:event) }
  let(:ledger) { event.ledger }
  let(:user) { create(:user) }

  let(:card_charge) { CardCharge.create!(merchant_network_id: "MERCHANT-1") }
  let!(:coffee) { mapped_item(amount_cents: -500, memo: "Coffee", datetime: Date.new(2024, 3, 1), linked_object_type: "CardCharge", linked_object_id: card_charge.id) }
  let!(:donation) { mapped_item(amount_cents: 2_000, memo: "Donation from Fiona", datetime: Date.new(2024, 1, 15), linked_object_type: "Donation") }

  # Ledger items recompute themselves from their canonical transactions, which
  # these don't have, so pin the values under test (and a ct_count, without which
  # the query treats the item as empty and skips it).
  def mapped_item(**attrs)
    item = create(:ledger_item, **attrs.slice(:amount_cents, :memo, :datetime))
    Ledger::Mapping.create!(ledger:, ledger_item: item, on_primary_ledger: true)
    item.update_columns(ct_count: 1, **attrs)
    item
  end

  def build_export(as:, query: {}, **attributes)
    ::Ledger::Query.new(query).export(as:, ledgers: [ledger], event_id: event.id, requested_by: user, **attributes).run
  end

  describe Export::Ledger::Item::Csv do
    it "exports every item the query matches" do
      rows = CSV.parse(build_export(as: :csv).content, headers: true)

      expect(rows.map { |row| row["memo"] }).to contain_exactly("Coffee", "Donation from Fiona")
      expect(rows.find { |row| row["memo"] == "Coffee" }.to_h).to include(
        "date"         => "2024-03-01",
        "amount_cents" => "-500",
        "amount"       => "-5.00"
      )
    end

    it "exports only what a filtered query matches" do
      export = build_export(as: :csv, query: { amount_cents: { "$gt" => 0 } })

      expect(CSV.parse(export.content, headers: true).map { |row| row["memo"] }).to eq(["Donation from Fiona"])
    end

    it "keeps honouring the filters after a round trip through the database" do
      export = build_export(as: :csv, query: { datetime: { "$gte" => Date.new(2024, 2, 1) } })
      export.save!

      # The async path regenerates the file from the stored export, long after
      # the request that asked for it is gone.
      expect(CSV.parse(Export.find(export.id).content, headers: true).map { |row| row["memo"] }).to eq(["Coffee"])
    end

    it "includes the organization's own tags" do
      tag = Tag.create!(event:, label: "Travel", emoji: "✈️", color: "red")
      HcbCodeTag.create!(hcb_code: create(:hcb_code, ledger_item: coffee), tag:)
      coffee.update_columns(ct_count: 1, memo: "Coffee")

      rows = CSV.parse(build_export(as: :csv).content, headers: true)

      expect(rows.find { |row| row["memo"] == "Coffee" }["tags"]).to eq("Travel")
    end

    it "escapes values that a spreadsheet would read as a formula" do
      mapped_item(amount_cents: -100, memo: "=1+1+cmd|'/c calc'!A1", datetime: Date.new(2024, 3, 2))

      memos = CSV.parse(build_export(as: :csv).content, headers: true).map { |row| row["memo"] }

      expect(memos).to include("'=1+1+cmd|'/c calc'!A1")
    end

    it "redacts account verification amounts from transparency viewers" do
      mapped_item(amount_cents: 42, memo: "ACCTVERIFY deposit", datetime: Date.new(2024, 3, 3))

      rows = CSV.parse(build_export(as: :csv, public_only: true).content, headers: true)

      expect(rows.find { |row| row["memo"] == "ACCTVERIFY deposit" }.to_h).to include("amount_cents" => "0", "amount" => "0.00")
    end
  end

  describe Export::Ledger::Item::Json do
    it "exports the items the query matches" do
      rows = JSON.parse(build_export(as: :json, query: { amount_cents: { "$lt" => 0 } }).content)

      expect(rows.length).to eq(1)
      expect(rows.first).to include("memo" => "Coffee", "amount_cents" => -500, "date" => "2024-03-01")
    end
  end

  describe Export::Ledger::Item::Journal do
    it "books expenses and income to their own accounts" do
      content = build_export(as: :ledger).content

      expect(content).to include("Expenses:", "-5.00")
      expect(content).to include("Income:Donation", "20.00")
    end

    it "exports only what a filtered query matches" do
      content = build_export(as: :ledger, query: { amount_cents: { "$lt" => 0 } }).content

      expect(content).to include("Coffee")
      expect(content).not_to include("Donation from Fiona")
    end
  end

  describe "naming" do
    it "says so when the export is filtered" do
      export = build_export(as: :csv, filtered: true)

      expect(export.filename).to match(/\A#{event.slug}_filtered_transactions_\d{12}\.csv\z/)
      expect(export.label).to include("filtered transactions", event.name)
    end

    it "says so when it isn't" do
      export = build_export(as: :csv)

      expect(export.filename).to match(/\A#{event.slug}_transactions_\d{12}\.csv\z/)
      expect(export.label).to include("all transactions", event.name)
    end
  end

  describe "#async?" do
    it "serves a small export inline" do
      expect(build_export(as: :csv).async?).to be(false)
    end

    it "emails an export bigger than the threshold" do
      stub_const("Export::Ledger::Item::Base::ASYNC_THRESHOLD", 1)

      expect(build_export(as: :csv).async?).to be(true)
    end

    it "counts only what the query matches" do
      stub_const("Export::Ledger::Item::Base::ASYNC_THRESHOLD", 1)

      expect(build_export(as: :csv, query: { amount_cents: { "$lt" => 0 } }).async?).to be(false)
    end
  end
end
