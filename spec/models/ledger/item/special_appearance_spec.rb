# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::Item::SpecialAppearance do
  let(:ids) { EventMappingEngine::EventIds }

  describe ".find_by_key" do
    it "resolves a key, as either a string or a symbol" do
      expect(described_class.find_by_key("hackathon_grant").title).to eq("Hackathon grant")
      expect(described_class.find_by_key(:hackathon_grant)).to be(described_class.find_by_key("hackathon_grant"))
    end

    it "resolves an unknown or blank key to nil rather than raising" do
      expect(described_class.find_by_key("a_grant_that_never_existed")).to be_nil
      expect(described_class.find_by_key(nil)).to be_nil
      expect(described_class.find_by_key("")).to be_nil
    end
  end

  describe ".find_by_linked_object" do
    it "matches the incoming leg of a transfer out of the appearance's fund" do
      disbursement = Disbursement.new(source_event_id: ids::HACKATHON_GRANT_FUND, created_at: Time.current)

      expect(described_class.find_by_linked_object(disbursement.incoming_disbursement).key).to eq("hackathon_grant")
    end

    # A ledger item's linked object is always one of the lenses, and they descend
    # from Disbursement::Base rather than Disbursement — so a type guard on
    # Disbursement would match nothing that actually reaches this code.
    #
    # Only the incoming lens qualifies: the fund's own ledger sees the outgoing
    # leg of every grant it pays out, and that side shouldn't take on the
    # recipient-facing appearance meant for the grant showing up in their ledger.
    it "matches through the incoming lens only, not the outgoing one" do
      disbursement = Disbursement.new(source_event_id: ids::GENE_HAAS_GRANT_FUND, created_at: Time.current)

      expect(described_class.find_by_linked_object(disbursement.becomes(Disbursement::Incoming)).key).to eq("gene_haas_grant")
      expect(described_class.find_by_linked_object(disbursement.becomes(Disbursement::Outgoing))).to be_nil
    end

    it "does not match a transfer out of an unrelated event" do
      disbursement = Disbursement.new(source_event_id: 1, created_at: Time.current)

      expect(described_class.find_by_linked_object(disbursement.incoming_disbursement)).to be_nil
    end

    # Non-disbursements may have special appearances in the future in which case this test would be updated.
    it "does not match a non-disbursement, or nothing at all" do
      expect(described_class.find_by_linked_object(CardCharge.new)).to be_nil
      expect(described_class.find_by_linked_object(nil)).to be_nil
    end

    it "honors an appearance's cutoff date" do
      before_cutoff = Disbursement.new(source_event_id: ids::ARGOSY_GRANT_FUND, created_at: Time.zone.local(2024, 8, 31))
      after_cutoff = Disbursement.new(source_event_id: ids::ARGOSY_GRANT_FUND, created_at: Time.zone.local(2024, 9, 2))

      expect(described_class.find_by_linked_object(before_cutoff.incoming_disbursement)).to be_nil
      expect(described_class.find_by_linked_object(after_cutoff.incoming_disbursement).key).to eq("argosy_grant_2024")
    end

    it "matches every fund an appearance names" do
      disbursement = Disbursement.new(source_event_id: ids::ARGOSY_GRANT_FUND_2025, created_at: Time.zone.local(2025, 3, 1))

      expect(described_class.find_by_linked_object(disbursement.incoming_disbursement).key).to eq("argosy_grant_2024")
    end

    it "never assigns a retired appearance (one with no qualifier)" do
      retired = described_class.new(key: :retired, title: "Retired", memo: "Retired", css_class: "x", icon: "x")

      expect(retired.applies_to?(Disbursement.new)).to be(false)
    end

    it "matches a transfer that issued a card grant, through either lens" do
      # An admin sender, so the grant's transfer doesn't need a funded event.
      disbursement = create(:card_grant, sent_by: create(:user, :make_admin)).disbursement

      expect(described_class.find_by_linked_object(disbursement.incoming_disbursement).key).to eq("card_grant")
      expect(described_class.find_by_linked_object(disbursement.outgoing_disbursement).key).to eq("card_grant")
    end

    it "matches a topup or withdrawal, not just the disbursement that created the grant" do
      # Topups/withdrawals are separate disbursements tied to the grant's subledger,
      # not to card_grants.disbursement_id, so they don't show up via `#card_grant`.
      card_grant = create(:card_grant, sent_by: create(:user, :make_admin))

      card_grant.topup!(amount_cents: 500)
      topup = card_grant.topup_disbursements.last
      expect(described_class.find_by_linked_object(topup.incoming_disbursement).key).to eq("card_grant")
      expect(described_class.find_by_linked_object(topup.outgoing_disbursement).key).to eq("card_grant")

      card_grant.withdraw!(amount_cents: 500)
      withdrawal = card_grant.withdrawal_disbursements.last
      expect(described_class.find_by_linked_object(withdrawal.incoming_disbursement).key).to eq("card_grant")
      expect(described_class.find_by_linked_object(withdrawal.outgoing_disbursement).key).to eq("card_grant")
    end

    it "does not match a transfer with no card grant" do
      expect(described_class.find_by_linked_object(create(:disbursement).incoming_disbursement)).to be_nil
    end
  end

  describe "an icon-only appearance" do
    subject(:card_grant) { described_class.find_by_key(:card_grant) }

    # It overrides nothing else, so the memo, styling, and title stay whatever the
    # item would have shown — see Ledger::Item#calculate_system_memo, which says
    # something different for a grant, a topup, and a withdrawal.
    it "carries an icon and nothing else" do
      expect(card_grant.icon).to eq("bag")
      expect(card_grant.memo).to be_nil
      expect(card_grant.css_class).to be_nil
      expect(card_grant.title).to be_nil
    end

    it "sorts after the fund appearances, which say more about the transfer" do
      expect(described_class::ALL.last).to be(card_grant)
    end
  end

  describe described_class::Type do
    subject(:type) { described_class.new }

    it "casts a key to an appearance and serializes it back" do
      appearance = Ledger::Item::SpecialAppearance.find_by_key(:gene_haas_grant)

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

  # The legacy transaction views keep their own copy of the grant definitions in
  # Disbursement::SPECIAL_APPEARANCES. While both exist they have to agree, or a
  # grant renamed in one place renders two different ways depending on the page.
  # (The registry is allowed to hold appearances the legacy hash doesn't, like the
  # card grant one, which only the Ledger knows about.)
  it "agrees with the legacy Disbursement::SPECIAL_APPEARANCES definitions" do
    Disbursement::SPECIAL_APPEARANCES.each do |key, legacy|
      appearance = described_class.find_by_key(key)

      expect(appearance).to be_present, "#{key} is defined for the legacy views but missing from the registry"
      expect(legacy[:title]).to eq(appearance.title)
      expect(legacy[:memo]).to eq(appearance.memo)
      expect(legacy[:css_class]).to eq(appearance.css_class)
      expect(legacy[:icon]).to eq(appearance.icon)
    end
  end
end
