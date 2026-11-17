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

  describe "membership actions" do
    def user_with_role(role, on:)
      create(:user).tap { |user| create(:organizer_position, user:, event: on, role:) }
    end

    context "for a charge on a card grant's ledger" do
      # Stub transfer_money to avoid disbursement side effects (see ledger_spec.rb)
      before { allow_any_instance_of(CardGrant).to receive(:transfer_money) }

      let(:parent_event) { create(:event) }
      let(:event) { create(:event, parent: parent_event) }
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

      it "lets a member of the grant's organization rename it, flag it as personal, and mark it as repaid" do
        policy = described_class.new(user_with_role(:member, on: event), item)

        expect(policy.rename?).to be(true)
        expect(policy.invoice_as_personal_transaction?).to be(true)
        expect(policy.mark_repayment?).to be(true)
      end

      it "lets a manager of a parent organization rename it" do
        expect(described_class.new(user_with_role(:manager, on: parent_event), item).rename?).to be(true)
      end

      it "refuses renaming to a member of a parent organization" do
        expect(described_class.new(user_with_role(:member, on: parent_event), item).rename?).to be(false)
      end

      it "refuses renaming to a reader of the grant's organization" do
        expect(described_class.new(user_with_role(:reader, on: event), item).rename?).to be(false)
      end

      it "refuses renaming to the grantee" do
        expect(described_class.new(grantee, item).rename?).to be(false)
      end

      it "refuses renaming to a member of an unrelated organization" do
        expect(described_class.new(user_with_role(:member, on: create(:event)), item).rename?).to be(false)
      end

      it "refuses pinning, since a card grant's ledger has no transaction list to pin to" do
        expect(described_class.new(user_with_role(:member, on: event), item).pin?).to be(false)
        expect(described_class.new(create(:user, :make_admin), item).unpin?).to be(false)
      end
    end

    context "for an item on an organization's ledger" do
      before { create(:ledger_mapping, :on_primary, ledger: event.ledger, ledger_item: item) }

      it "lets a member pin, unpin, and rename it" do
        policy = described_class.new(user_with_role(:member, on: event), item)

        expect(policy.pin?).to be(true)
        expect(policy.unpin?).to be(true)
        expect(policy.rename?).to be(true)
      end

      it "refuses a reader" do
        policy = described_class.new(user_with_role(:reader, on: event), item)

        expect(policy.pin?).to be(false)
        expect(policy.rename?).to be(false)
      end
    end
  end
end
