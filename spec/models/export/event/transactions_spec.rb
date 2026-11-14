# frozen_string_literal: true

require "rails_helper"

# The legacy whole-organization exports, driven by canonical transactions.
RSpec.describe Export::Event::Transactions do
  let(:event) { create(:event) }
  let(:user) { create(:user) }

  def mapped_transaction(**attrs)
    ct = create(:canonical_transaction, hcb_code: create(:hcb_code).hcb_code, **attrs)
    create(:canonical_event_mapping, canonical_transaction: ct, event:)
    ct
  end

  let!(:coffee) { mapped_transaction(amount_cents: -500, custom_memo: "Coffee", date: Date.new(2024, 3, 1)) }
  let!(:donation) { mapped_transaction(amount_cents: 2_000, custom_memo: "Donation from Fiona", date: Date.new(2024, 1, 15)) }

  def build_export(klass, **attributes)
    klass.new(requested_by: user, event_id: event.id, public_only: false, **attributes)
  end

  describe "query count" do
    def stripe_transaction(memo)
      mapped_transaction(amount_cents: -300, custom_memo: memo, date: Date.new(2024, 3, 4), transaction_source: create(:raw_stripe_transaction))
    end

    def queries_to_export(klass)
      count = 0
      counter = ->(_name, _start, _finish, _id, payload) { count += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name]) }

      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { build_export(klass).content }

      count
    end

    [Export::Event::Transactions::Csv, Export::Event::Transactions::Json, Export::Event::Transactions::Ledger].each do |klass|
      it "#{klass.name.demodulize} doesn't query per transaction" do
        stripe_transaction("Bread")
        queries_to_export(klass) # the first export pays for one-time caches; measure the second
        with_one = queries_to_export(klass)

        stripe_transaction("Croissant")
        stripe_transaction("Taxi")

        expect(queries_to_export(klass)).to eq(with_one)
      end
    end
  end

  describe Export::Event::Transactions::Csv do
    it "exports every transaction, newest first" do
      rows = CSV.parse(build_export(described_class).content, headers: true)

      expect(rows.map { |row| row["memo"] }).to eq(["Coffee", "Donation from Fiona"])
      expect(rows.first.to_h).to include("date" => "2024-03-01", "amount_cents" => "-500", "amount" => "-5.00")
    end

    it "honours a date range" do
      export = build_export(described_class, start_date: Date.new(2024, 2, 1), end_date: Date.new(2024, 3, 31))

      expect(CSV.parse(export.content, headers: true).map { |row| row["memo"] }).to eq(["Coffee"])
    end

    it "decides whether to email the export by what it will contain" do
      stub_const("Export::ASYNC_THRESHOLD", 1)

      expect(build_export(described_class).async?).to be(true)
      expect(build_export(described_class, start_date: Date.new(2024, 2, 1), end_date: Date.new(2024, 3, 31)).async?).to be(false)
    end

    it "names itself" do
      export = build_export(described_class)

      expect(export.mime_type).to eq("text/csv")
      expect(export.filename).to match(/\A#{event.slug}_transactions_\d{12}\.csv\z/)
      expect(export.label).to eq("CSV transaction export for #{event.name}")
    end
  end

  describe Export::Event::Transactions::Json do
    it "exports every transaction, newest first" do
      rows = JSON.parse(build_export(described_class).content)

      expect(rows.map { |row| row["memo"] }).to eq(["Coffee", "Donation from Fiona"])
      expect(rows.first).to include("date" => "2024-03-01", "amount_cents" => -500, "tags" => "", "comments" => [], "user" => nil)
    end

    it "names itself" do
      export = build_export(described_class)

      expect(export.mime_type).to eq("application/json")
      expect(export.filename).to match(/\A#{event.slug}_transactions_\d{12}\.json\z/)
      expect(export.label).to eq("JSON transaction export for #{event.name}")
    end
  end

  describe Export::Event::Transactions::Ledger do
    it "books expenses and income to their own accounts" do
      content = build_export(described_class).content

      expect(content).to include("Coffee", "Expenses:Transfer", "-5.00")
      expect(content).to include("Donation from Fiona", "Income:Transfer", "20.00")
    end

    it "books a card charge to its merchant's category" do
      mapped_transaction(amount_cents: -300, custom_memo: "Bread", date: Date.new(2024, 3, 4), transaction_source: create(:raw_stripe_transaction, stripe_merchant_category: "bakeries"))

      expect(build_export(described_class).content).to include("Expenses:Bakeries")
    end

    it "names itself" do
      export = build_export(described_class)

      expect(export.mime_type).to eq("text/ledger")
      expect(export.filename).to match(/\A#{event.slug}_transactions_\d{12}\.ledger\z/)
      expect(export.label).to eq("Ledger export for #{event.name}")
    end
  end
end
