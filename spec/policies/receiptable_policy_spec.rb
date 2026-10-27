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

      it "does not raise for an unmapped item with no primary ledger" do
        unmapped_item = create(:ledger_item)

        expect { described_class.new(create(:user), unmapped_item).upload? }.not_to raise_error
        expect(described_class.new(create(:user), unmapped_item).upload?).to be_falsey
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
