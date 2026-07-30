# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::BackfillLedgerItemSpecialAppearancesTask do
  # The grant funds are fixed-id events that the seeds create, so find rather than
  # create when one is already there.
  def fund(id)
    Event.find_by(id:) || create(:event, id:)
  end

  # A row as it looked before the column existed: no appearance, and the memo the
  # item would have had without one.
  def item_for(disbursement)
    item = create(:ledger_item, linked_object: disbursement.outgoing_disbursement)
    item.update_column(:special_appearance, nil)
    item.reload.update_column(:memo, item.calculate_system_memo)
    item.reload
  end

  describe "a transfer out of a grant fund" do
    let(:appearance) { Ledger::Item::SpecialAppearance.find(:hackathon_grant) }
    let(:disbursement) { create(:disbursement, source_event: fund(EventMappingEngine::EventIds::HACKATHON_GRANT_FUND)) }

    it "sets the appearance and brings the memo with it" do
      item = item_for(disbursement)
      expect(item.memo).not_to eq(appearance.memo) # the memo was never a record of the appearance

      described_class.new.process(item)

      expect(item.reload.special_appearance).to be(appearance)
      expect(item.memo).to eq(appearance.memo)
      expect(item.icon).to eq(appearance.icon)
    end

    it "records no paper_trail version, since the change is cosmetic" do
      item = item_for(disbursement)

      expect { described_class.new.process(item) }.not_to(change { item.versions.count })
    end

    it "leaves a transfer that earns no appearance alone" do
      item = item_for(create(:disbursement))
      memo = item.memo

      described_class.new.process(item)

      expect(item.reload.special_appearance).to be_nil
      expect(item.memo).to eq(memo)
    end
  end

  describe "a card grant transfer" do
    # An admin sender, so the grant's transfer doesn't need a funded event.
    let(:disbursement) { create(:card_grant, sent_by: create(:user, :make_admin)).disbursement }

    it "re-derives the appearance from the card grant" do
      item = item_for(disbursement)

      described_class.new.process(item)

      expect(item.reload.special_appearance.key).to eq("card_grant")
      expect(item.icon).to eq("bag")
    end

    it "keeps the memo it already had, since the appearance overrides no memo" do
      item = item_for(disbursement)
      memo = item.memo

      described_class.new.process(item)

      expect(item.reload.memo).to eq(memo)
    end
  end

  describe "#collection" do
    it "collects transfers out of a fund and transfers carrying a card grant" do
      from_fund = item_for(create(:disbursement, source_event: fund(EventMappingEngine::EventIds::GENE_HAAS_GRANT_FUND)))
      card_grant = item_for(create(:card_grant, sent_by: create(:user, :make_admin)).disbursement)

      expect(described_class.new.collection).to include(from_fund, card_grant)
    end

    it "skips plain transfers, and items that already have an appearance" do
      plain = item_for(create(:disbursement))
      done = item_for(create(:disbursement, source_event: fund(EventMappingEngine::EventIds::GENE_HAAS_GRANT_FUND)))
      done.update_column(:special_appearance, "gene_haas_grant")

      collection = described_class.new.collection

      expect(collection).not_to include(plain)
      expect(collection).not_to include(done)
    end
  end
end
