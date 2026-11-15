# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::ItemPolicy, type: :policy do
  let(:event) { create(:event) }
  let(:item) { create(:ledger_item) }
  let(:tag) { event.tags.create!(label: "Snacks", emoji: "🍕", color: "muted") }

  before { create(:ledger_mapping, :on_primary, ledger: event.ledger, ledger_item: item) }

  describe "#toggle_tag?" do
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
end
