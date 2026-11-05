# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::Query::Export, type: :model do
  let(:event) { create(:event) }
  let(:ledger) { event.ledger }
  let(:query) { Ledger::Query.new({ amount_cents: { "$gt" => 100 } }) }

  def build_export(**options)
    described_class.new(query:, ledgers: [ledger], **options)
  end

  describe "#export_class" do
    it "picks an export class per format" do
      expect(build_export(as: :csv).export_class).to eq(Export::Ledger::Item::Csv)
      expect(build_export(as: :json).export_class).to eq(Export::Ledger::Item::Json)
      expect(build_export(as: :ledger).export_class).to eq(Export::Ledger::Item::Journal)
    end

    it "accepts a format given as a string, as it arrives from a request" do
      expect(build_export(as: "csv").export_class).to eq(Export::Ledger::Item::Csv)
    end

    it "rejects a format it can't export" do
      expect { build_export(as: :xlsx).export_class }
        .to raise_error(Ledger::Query::Error, /Unsupported export format/)
    end

    it "covers every format it advertises" do
      expect(described_class::FORMATS.map { |as| build_export(as:).export_class }).to all(be < Export)
    end
  end

  describe "#run" do
    it "builds the export around the query, not the rows it matched" do
      export = build_export(as: :csv).run

      expect(export).to be_a(Export::Ledger::Item::Csv)
      expect(export.query).to eq({ "amount_cents" => { "$gt" => 100 } })
      expect(export.ledger_ids).to eq([ledger.id])
    end

    it "accepts ledger ids as well as ledgers" do
      export = described_class.new(query:, as: :csv, ledgers: [ledger.id]).run

      expect(export.ledger_ids).to eq([ledger.id])
    end

    it "passes the remaining attributes through to the export" do
      export = build_export(as: :csv, event_id: event.id, public_only: true, filtered: true).run

      expect(export.event_id).to eq(event.id)
      expect(export.public_only).to be(true)
      expect(export.filtered).to be(true)
    end

    it "only opts out of ledger scoping on a literal true" do
      expect(build_export(as: :csv, all_ledgers: "true").run.all_ledgers).to be(false)
      expect(build_export(as: :csv, all_ledgers: true).run.all_ledgers).to be(true)
    end
  end
end
