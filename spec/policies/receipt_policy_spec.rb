# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReceiptPolicy, type: :policy do
  describe "#destroy?" do
    context "when the receipt is on a Ledger::Item" do
      let(:ledger_item) { create(:ledger_item, :with_primary_ledger) }
      let(:event) { ledger_item.primary_ledger.event }
      let(:receipt) { Receipt.new(receiptable: ledger_item, user: create(:user), upload_method: :api) }

      it "authorizes a member of the item's primary ledger event" do
        organizer_position = create(:organizer_position, event:, role: :member)

        expect(described_class.new(organizer_position.user, receipt).destroy?).to be(true)
      end

      it "does not authorize an unrelated user" do
        expect(described_class.new(create(:user), receipt).destroy?).to be(false)
      end

      it "does not raise for an unmapped item with no primary ledger" do
        unmapped_receipt = Receipt.new(receiptable: create(:ledger_item), user: create(:user), upload_method: :api)

        expect(described_class.new(create(:user), unmapped_receipt).destroy?).to be(false)
      end
    end
  end
end
