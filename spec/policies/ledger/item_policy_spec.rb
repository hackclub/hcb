# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::ItemPolicy, type: :policy do
  let(:event) { create(:event) }
  let(:item) { create(:ledger_item) }
  let(:tag) { event.tags.create!(label: "Snacks", emoji: "🍕", color: "muted") }

  describe "#show?" do
    # Stub transfer_money to avoid disbursement side effects (see ledger_spec.rb)
    before { allow_any_instance_of(CardGrant).to receive(:transfer_money) }

    let(:grantee) { create(:user) }
    let(:card_grant) do
      card = create(:stripe_card, :with_stripe_id, event:, stripe_cardholder: create(:stripe_cardholder, user: grantee))
      create(:card_grant, event:, user: grantee, stripe_card: card)
    end
    let(:item) do
      charge = create(:canonical_pending_transaction, event:, amount_cents: -1000, raw_pending_stripe_transaction: create(:raw_pending_stripe_transaction, stripe_card: card_grant.stripe_card))

      charge.local_hcb_code.ledger_item.tap do |item|
        Ledger::Mapping.map_primary!(ledger: card_grant.ledger, ledger_item: item, mapped_by: create(:user, :make_admin))
      end
    end

    it "permits a reader of the grant's event" do
      reader = create(:user)
      create(:organizer_position, user: reader, event: card_grant.event, role: :reader)

      expect(described_class.new(reader, item).show?).to be(true)
    end

    it "permits the grantee for a charge on their own grant" do
      expect(described_class.new(grantee, item).show?).to be(true)
    end

    it "refuses a signed-in user with no position who didn't make the charge" do
      expect(described_class.new(create(:user), item).show?).to be(false)
    end

    it "refuses a signed-out visitor" do
      expect(described_class.new(nil, item).show?).to be(false)
    end

    it "refuses the grantee for an item on their grant's ledger that isn't a card charge" do
      transfer = create(:ledger_item)
      Ledger::Mapping.map_primary!(ledger: card_grant.ledger, ledger_item: transfer, mapped_by: create(:user, :make_admin))

      expect(described_class.new(grantee, transfer).show?).to be(false)
    end

    it "refuses the grantee of another grant" do
      other_grantee = create(:user)
      create(:card_grant, event:, user: other_grantee)

      expect(described_class.new(other_grantee, item).show?).to be(false)
    end

    context "for a charge on a regular card" do
      let(:cardholder) { create(:user) }
      let(:card) { create(:stripe_card, :with_stripe_id, event:, stripe_cardholder: create(:stripe_cardholder, user: cardholder)) }
      let(:item) do
        charge = create(:canonical_pending_transaction, event:, amount_cents: -1000, raw_pending_stripe_transaction: create(:raw_pending_stripe_transaction, stripe_card: card))

        charge.local_hcb_code.ledger_item.tap do |item|
          Ledger::Mapping.map_primary!(ledger: event.ledger, ledger_item: item, mapped_by: create(:user, :make_admin))
        end
      end

      it "permits the cardholder without a position in the event" do
        expect(described_class.new(cardholder, item).show?).to be(true)
      end

      it "refuses another cardholder in the event" do
        other_cardholder = create(:user)
        create(:stripe_card, :with_stripe_id, event:, stripe_cardholder: create(:stripe_cardholder, user: other_cardholder))

        expect(described_class.new(other_cardholder, item).show?).to be(false)
      end
    end
  end

  describe "#toggle_tag?" do
    before { create(:ledger_mapping, :on_primary, ledger: event.ledger, ledger_item: item) }

    context "for a member of the item's event" do
      let(:user) do
        create(:user).tap { |u| create(:organizer_position, user: u, event:, role: :member) }
      end

      it "permits toggling a tag from that event" do
        expect(described_class.new(user, item).toggle_tag?(tag)).to be(true)
      end

      it "permits the membership-only check when no tag is given" do
        expect(described_class.new(user, item).toggle_tag?).to be(true)
      end

      it "refuses a tag from an unrelated event" do
        other_tag = create(:event).tags.create!(label: "Other", emoji: "🎉", color: "red")

        expect(described_class.new(user, item).toggle_tag?(other_tag)).to be(false)
      end
    end

    it "refuses a non-member" do
      expect(described_class.new(create(:user), item).toggle_tag?(tag)).to be(false)
    end

    it "refuses a signed-out visitor" do
      expect(described_class.new(nil, item).toggle_tag?(tag)).to be(false)
    end
  end

  describe "#dispute?" do
    before { create(:ledger_mapping, :on_primary, ledger: event.ledger, ledger_item: item) }

    it "permits a member of the item's event" do
      member = create(:user).tap { |u| create(:organizer_position, user: u, event:, role: :member) }

      expect(described_class.new(member, item).dispute?).to be(true)
    end

    it "refuses a reader" do
      reader = create(:user).tap { |u| create(:organizer_position, user: u, event:, role: :reader) }

      expect(described_class.new(reader, item).dispute?).to be(false)
    end

    it "refuses a signed-out visitor" do
      expect(described_class.new(nil, item).dispute?).to be(false)
    end

    context "on a card grant's ledger" do
      let(:grant_event) { create(:event, :with_positive_balance) }
      let(:grant_item) { create(:ledger_item) }

      before do
        create(:ledger_mapping, :on_primary, ledger: create(:card_grant, event: grant_event).ledger, ledger_item: grant_item)
      end

      it "permits a member of the grant's organization" do
        member = create(:user).tap { |u| create(:organizer_position, user: u, event: grant_event, role: :member) }

        expect(described_class.new(member, grant_item).dispute?).to be(true)
        expect(described_class.new(member, grant_item).rename?).to be(true)
      end

      it "refuses someone outside the grant's organization" do
        expect(described_class.new(create(:user), grant_item).dispute?).to be(false)
      end
    end
  end
end
