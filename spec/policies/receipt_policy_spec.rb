# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReceiptPolicy, type: :policy do
  describe "#destroy?" do
    context "when the receipt is on a Ledger::Item" do
      def receipt_on(ledger_item)
        Receipt.new(receiptable: ledger_item, user: create(:user), upload_method: :api)
      end

      context "whose primary ledger belongs to an event" do
        let(:ledger_item) { create(:ledger_item, :with_primary_ledger) }
        let(:event) { ledger_item.primary_ledger.event }

        it "authorizes a member of the event" do
          organizer_position = create(:organizer_position, event:)

          expect(described_class.new(organizer_position.user, receipt_on(ledger_item)).destroy?).to be(true)
        end

        it "does not authorize an unrelated user" do
          expect(described_class.new(create(:user), receipt_on(ledger_item)).destroy?).to be_falsey
        end
      end

      context "whose primary ledger belongs to a card grant" do
        let(:card_grant) { create(:card_grant) }
        let(:ledger_item) do
          create(:ledger_item).tap do |item|
            Ledger::Mapping.create!(ledger: card_grant.ledger, ledger_item: item, on_primary_ledger: true)
          end
        end

        it "authorizes a member of the card grant's event" do
          organizer_position = create(:organizer_position, event: card_grant.event)

          expect(described_class.new(organizer_position.user, receipt_on(ledger_item)).destroy?).to be(true)
        end

        it "does not authorize an unrelated user" do
          expect(described_class.new(create(:user), receipt_on(ledger_item)).destroy?).to be_falsey
        end
      end

      it "does not raise for an unmapped item with no primary ledger" do
        receipt = receipt_on(create(:ledger_item))

        expect { described_class.new(create(:user), receipt).destroy? }.not_to raise_error
        expect(described_class.new(create(:user), receipt).destroy?).to be_falsey
      end
    end
  end
end
