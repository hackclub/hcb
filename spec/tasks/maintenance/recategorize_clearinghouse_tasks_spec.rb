# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Clearinghouse recategorization tasks" do
  let(:clearinghouse) { create(:event) }
  let(:organization) { create(:event) }

  def slug_of(transaction)
    transaction.reload.category&.slug
  end

  # Transactions work out their own HCB code on create, so pin it afterwards.
  def on_hcb_code(transaction, hcb_code)
    transaction.update_column(:hcb_code, hcb_code)
    transaction
  end

  describe Maintenance::RecategorizeClearinghouseTransfersAsDonationsTask do
    def process(disbursement)
      described_class.new.process(disbursement)
    end

    it "only collects plain transfers out of the given clearing organizations" do
      benevity = create(:event)
      transfer = create(:disbursement, source_event: clearinghouse, event: organization)
      benevity_transfer = create(:disbursement, source_event: benevity, event: organization)
      create(:disbursement, source_event: create(:event), event: organization)
      create(:disbursement, source_event: clearinghouse, event: organization).update_column(:transfer_type, "repayment") # skips the repayment validations
      create(:disbursement, source_event: organization, event: clearinghouse)

      task = described_class.new.tap { |t| t.source_event_ids = "#{clearinghouse.id}, #{benevity.id}" }

      expect(task).to be_valid
      expect(task.collection).to contain_exactly(transfer, benevity_transfer)
      expect(described_class.new.tap { |t| t.source_event_ids = "abc" }).not_to be_valid
    end

    it "recategorizes the receiving side as a donation and leaves the Clearinghouse's side alone" do
      disbursement = create(:disbursement, source_event: clearinghouse, event: organization)
      incoming = on_hcb_code(create(:canonical_transaction, amount_cents: 1000, category_slug: "internal-transfer"), disbursement.incoming_hcb_code)
      incoming_pending = on_hcb_code(create(:canonical_pending_transaction, amount_cents: 1000, category_slug: "internal-transfer"), disbursement.incoming_hcb_code)
      outgoing = on_hcb_code(create(:canonical_transaction, amount_cents: -1000, category_slug: "internal-transfer"), disbursement.outgoing_hcb_code)

      process(disbursement)

      expect(slug_of(incoming)).to eq("donations")
      expect(slug_of(incoming_pending)).to eq("donations")
      expect(slug_of(outgoing)).to eq("internal-transfer")
      expect(disbursement.reload.destination_transaction_category.slug).to eq("donations")
    end

    it "keeps a category the organization chose itself" do
      disbursement = create(:disbursement, source_event: clearinghouse, event: organization)
      incoming = on_hcb_code(create(:canonical_transaction, amount_cents: 1000), disbursement.incoming_hcb_code)
      TransactionCategoryService.new(model: incoming).set!(slug: "grants", assignment_strategy: "manual")

      process(disbursement)

      expect(slug_of(incoming)).to eq("grants")
    end
  end

  describe Maintenance::RecategorizeClearinghouseIncomeAsInternalTransfersTask do
    def add_transaction(event, amount_cents, category_slug: nil)
      ct = create(:canonical_transaction, amount_cents:, category_slug:)
      create(:canonical_event_mapping, canonical_transaction: ct, event:)
      ct
    end

    it "recategorizes money into the Clearinghouse as an internal transfer" do
      uncategorized = add_transaction(clearinghouse, 1000)
      donation = add_transaction(clearinghouse, 2000, category_slug: "donations")
      other = add_transaction(clearinghouse, 3000, category_slug: "grants")
      add_transaction(clearinghouse, -500)
      add_transaction(organization, 4000)

      task = described_class.new.tap { |t| t.clearinghouse_event_id = clearinghouse.id }
      expect(task.collection).to contain_exactly(uncategorized, donation, other)

      task.collection.each { |ct| task.process(ct) }

      expect(slug_of(uncategorized)).to eq("internal-transfer")
      expect(slug_of(donation)).to eq("internal-transfer")
      expect(slug_of(other)).to eq("grants")
    end
  end
end
