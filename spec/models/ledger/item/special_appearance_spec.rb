# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::Item::SpecialAppearance do
  let(:ids) { EventMappingEngine::EventIds }

  describe ".find" do
    it "resolves a key, as either a string or a symbol" do
      expect(described_class.find("hackathon_grant").title).to eq("Hackathon grant")
      expect(described_class.find(:hackathon_grant)).to be(described_class.find("hackathon_grant"))
    end

    it "resolves an unknown or blank key to nil rather than raising" do
      expect(described_class.find("a_grant_that_never_existed")).to be_nil
      expect(described_class.find(nil)).to be_nil
      expect(described_class.find("")).to be_nil
    end
  end

  describe ".for" do
    it "matches a transfer out of the appearance's fund" do
      disbursement = Disbursement.new(source_event_id: ids::HACKATHON_GRANT_FUND, created_at: Time.current)

      expect(described_class.for(disbursement).key).to eq("hackathon_grant")
    end

    # A ledger item's linked object is always one of the lenses, and they descend
    # from Disbursement::Base rather than Disbursement — so a type guard on
    # Disbursement would match nothing that actually reaches this code.
    it "matches through both the incoming and outgoing lens" do
      disbursement = Disbursement.new(source_event_id: ids::GENE_HAAS_GRANT_FUND, created_at: Time.current)

      expect(described_class.for(disbursement.becomes(Disbursement::Incoming)).key).to eq("gene_haas_grant")
      expect(described_class.for(disbursement.becomes(Disbursement::Outgoing)).key).to eq("gene_haas_grant")
    end

    it "does not match a transfer out of an unrelated event" do
      expect(described_class.for(Disbursement.new(source_event_id: 1, created_at: Time.current))).to be_nil
    end

    it "does not match a non-disbursement, or nothing at all" do
      expect(described_class.for(CardCharge.new)).to be_nil
      expect(described_class.for(nil)).to be_nil
    end

    it "honors an appearance's cutoff date" do
      before_cutoff = Disbursement.new(source_event_id: ids::ARGOSY_GRANT_FUND, created_at: Time.zone.local(2024, 8, 31))
      after_cutoff = Disbursement.new(source_event_id: ids::ARGOSY_GRANT_FUND, created_at: Time.zone.local(2024, 9, 2))

      expect(described_class.for(before_cutoff)).to be_nil
      expect(described_class.for(after_cutoff).key).to eq("argosy_grant_2024")
    end

    it "matches every fund an appearance names" do
      disbursement = Disbursement.new(source_event_id: ids::ARGOSY_GRANT_FUND_2025, created_at: Time.zone.local(2025, 3, 1))

      expect(described_class.for(disbursement).key).to eq("argosy_grant_2024")
    end

    it "never assigns a retired appearance (one with no qualifier)" do
      retired = described_class.new(key: :retired, title: "Retired", memo: "Retired", css_class: "x", icon: "x")

      expect(retired.applies_to?(Disbursement.new)).to be(false)
    end
  end

  describe described_class::Type do
    subject(:type) { described_class.new }

    it "casts a key to an appearance and serializes it back" do
      appearance = Ledger::Item::SpecialAppearance.find(:gene_haas_grant)

      expect(type.cast("gene_haas_grant")).to be(appearance)
      expect(type.serialize("gene_haas_grant")).to eq("gene_haas_grant")
      expect(type.serialize(appearance)).to eq("gene_haas_grant")
      expect(type.cast(appearance)).to be(appearance)
    end

    it "casts and serializes an unknown key to nil" do
      expect(type.cast("nope")).to be_nil
      expect(type.serialize("nope")).to be_nil
      expect(type.serialize(nil)).to be_nil
    end
  end

  # The Ledger column is the source of truth now, but the legacy transaction views
  # still read this hash — it has to keep its old shape until they're gone.
  describe "the legacy Disbursement::SPECIAL_APPEARANCES bridge" do
    it "exposes every appearance keyed by symbol, with the keys the views read" do
      expect(Disbursement::SPECIAL_APPEARANCES.keys).to eq(described_class::ALL.map { |a| a.key.to_sym })

      Disbursement::SPECIAL_APPEARANCES.each do |key, value|
        appearance = described_class.find(key)

        expect(value[:title]).to eq(appearance.title)
        expect(value[:memo]).to eq(appearance.memo)
        expect(value[:css_class]).to eq(appearance.css_class)
        expect(value[:icon]).to eq(appearance.icon)
        expect(value[:qualifier]).to eq(appearance.qualifier)
      end
    end

    it "still resolves a disbursement's appearance through the legacy methods" do
      disbursement = Disbursement.new(source_event_id: EventMappingEngine::EventIds::FIRST_TRANSPARENCY_GRANT_FUND, created_at: Time.current)

      expect(disbursement.special_appearance_name).to eq(:first_transparency_grant)
      expect(disbursement.special_appearance_memo).to eq("🤖 FIRST® Transparency Grant")
    end
  end
end
