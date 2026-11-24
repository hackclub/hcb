# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReceiptablePolicy, type: :policy do
  describe "#upload?" do
    context "when the record is a Ledger::Item" do
      let(:ledger_item) { create(:ledger_item, :with_primary_ledger) }
      let(:event) { ledger_item.primary_ledger.event }

      it "authorizes a member of the item's primary ledger event" do
        organizer_position = create(:organizer_position, event:)

        expect(described_class.new(organizer_position.user, ledger_item).upload?).to be(true)
      end

      it "does not authorize an unrelated user" do
        expect(described_class.new(create(:user), ledger_item).upload?).to be_falsey
      end

      it "authorizes a member of the card grant's event when the primary ledger belongs to a card grant" do
        card_grant = create(:card_grant)
        grant_item = create(:ledger_item)
        Ledger::Mapping.create!(ledger: card_grant.ledger, ledger_item: grant_item, on_primary_ledger: true)
        organizer_position = create(:organizer_position, event: card_grant.event)

        expect(described_class.new(organizer_position.user, grant_item).upload?).to be(true)
      end

      it "does not raise for an unmapped item with no primary ledger" do
        unmapped_item = create(:ledger_item)

        expect { described_class.new(create(:user), unmapped_item).upload? }.not_to raise_error
        expect(described_class.new(create(:user), unmapped_item).upload?).to be_falsey
      end
    end

    # A transaction's receipts are attached to its ledger item (#14106), so the
    # item has to grant exactly what its HCB code grants.
    context "when the record is a Ledger::Item with an HCB code" do
      include_context "card locking charges"

      let(:charge) do
        charge = create_settled_card_charge(user:, settled_at: 3.days.ago)
        # The Stripe payload the factory builds names the cardholder by database
        # id; HcbCodePolicy#user_made_purchase? resolves them by Stripe id.
        raw_stripe_transaction = charge.hcb_code.ct.transaction_source
        raw_stripe_transaction.update!(stripe_transaction: raw_stripe_transaction.stripe_transaction.merge("cardholder" => user.stripe_cardholder.stripe_id))
        charge.reload
      end

      it "authorizes the cardholder, who need not be a member of the organization" do
        expect(described_class.new(user, charge).upload?).to be(true)
        expect(described_class.new(user, charge.hcb_code).upload?).to be(true)
      end

      it "authorizes a member of an event the HCB code is on" do
        organizer_position = create(:organizer_position, event:)

        expect(described_class.new(organizer_position.user, charge).upload?).to be(true)
      end

      it "does not authorize an unrelated user" do
        expect(described_class.new(create(:user), charge).upload?).to be_falsey
      end
    end

    context "when the record is nil" do
      it "does not raise and is not authorized" do
        expect { described_class.new(create(:user), nil).upload? }.not_to raise_error
        expect(described_class.new(create(:user), nil).upload?).to be_falsey
      end
    end
  end

  describe "#link_modal?" do
    it "does not raise when the record is nil" do
      expect { described_class.new(create(:user), nil).link_modal? }.not_to raise_error
    end
  end
end
