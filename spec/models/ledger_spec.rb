# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger, type: :model do
  describe "associations" do
    it "belongs to event" do
      ledger = Ledger.new
      expect(ledger).to respond_to(:event)
    end

    it "belongs to card_grant" do
      ledger = Ledger.new
      expect(ledger).to respond_to(:card_grant)
    end

    it "has many mappings" do
      ledger = Ledger.new
      expect(ledger).to respond_to(:mappings)
    end

    it "has many items through mappings" do
      ledger = Ledger.new
      expect(ledger).to respond_to(:items)
    end

    describe "items association" do
      let(:ledger) do
        l = Ledger.new(primary: false)
        l.save(validate: false)
        l
      end
      let(:item1) { create(:ledger_item, memo: "Item 1") }
      let(:item2) { create(:ledger_item, memo: "Item 2") }
      let(:item3) { create(:ledger_item, memo: "Item 3") }

      it "returns items associated through mappings" do
        Ledger::Mapping.create!(
          ledger: ledger,
          ledger_item: item1,
          on_primary_ledger: false
        )
        Ledger::Mapping.create!(
          ledger: ledger,
          ledger_item: item2,
          on_primary_ledger: false
        )

        expect(ledger.items).to contain_exactly(item1, item2)
      end

      it "returns empty array when no mappings exist" do
        expect(ledger.items).to be_empty
      end

      it "only returns items mapped to this specific ledger" do
        other_ledger = Ledger.new(primary: false)
        other_ledger.save(validate: false)

        Ledger::Mapping.create!(
          ledger: ledger,
          ledger_item: item1,
          on_primary_ledger: false
        )
        Ledger::Mapping.create!(
          ledger: other_ledger,
          ledger_item: item2,
          on_primary_ledger: false
        )

        expect(ledger.items).to contain_exactly(item1)
        expect(other_ledger.items).to contain_exactly(item2)
      end
    end
  end

  describe "owner validation" do
    context "when primary is true" do
      context "with an event owner" do
        it "is valid" do
          event = create(:event)
          ledger = Ledger.new(primary: true, event: event)
          expect(ledger).to be_valid
        end
      end

      context "with a card_grant owner" do
        it "is valid" do
          card_grant = build_stubbed(:card_grant)
          ledger = Ledger.new(primary: true, card_grant_id: card_grant.id)
          expect(ledger).to be_valid
        end
      end

      context "with both event and card_grant owners" do
        it "is not valid" do
          event = create(:event)
          card_grant = build_stubbed(:card_grant)
          ledger = Ledger.new(primary: true, event: event, card_grant_id: card_grant.id)
          expect(ledger).not_to be_valid
          expect(ledger.errors[:base]).to include("Primary ledger cannot have more than one owner")
        end
      end

      context "with no owner" do
        it "is not valid" do
          ledger = Ledger.new(primary: true)
          expect(ledger).not_to be_valid
          expect(ledger.errors[:base]).to include("Primary ledger must have an owner (event or card grant)")
        end
      end
    end

    context "when primary is false" do
      context "with no owner" do
        it "is valid" do
          ledger = Ledger.new(primary: false)
          expect(ledger).to be_valid
        end
      end

      context "with an event owner" do
        it "is not valid" do
          event = create(:event)
          ledger = Ledger.new(primary: false, event: event)
          expect(ledger).not_to be_valid
          expect(ledger.errors[:base]).to include("Non-primary ledger cannot have an owner")
        end
      end

      context "with a card_grant owner" do
        it "is not valid" do
          card_grant = build_stubbed(:card_grant)
          ledger = Ledger.new(primary: false, card_grant_id: card_grant.id)
          expect(ledger).not_to be_valid
          expect(ledger.errors[:base]).to include("Non-primary ledger cannot have an owner")
        end
      end

      context "with both owners" do
        it "is not valid" do
          event = create(:event)
          card_grant = build_stubbed(:card_grant)
          ledger = Ledger.new(primary: false, event: event, card_grant_id: card_grant.id)
          expect(ledger).not_to be_valid
          expect(ledger.errors[:base]).to include("Non-primary ledger cannot have an owner")
        end
      end
    end
  end

  describe "database constraint" do
    context "primary ledger" do
      it "enforces must have exactly one owner at database level" do
        # Test: primary with no owner should fail
        expect {
          ledger = Ledger.new(primary: true)
          ledger.save(validate: false)
        }.to raise_error(ActiveRecord::StatementInvalid)
      end

      it "enforces cannot have both owners at database level" do
        event = create(:event)
        card_grant = build_stubbed(:card_grant)

        # Test: primary with both owners should fail
        expect {
          ledger = Ledger.new(primary: true, event: event, card_grant_id: card_grant.id)
          ledger.save(validate: false)
        }.to raise_error(ActiveRecord::StatementInvalid)
      end

      it "allows primary with event owner" do
        event = create(:event)
        ledger = Ledger.new(primary: true, event: event)
        ledger.save(validate: false)
        expect(ledger.persisted?).to be true
      end

      it "allows primary with card_grant owner" do
        # Skip foreign key for this test since we don't want to trigger card_grant side effects
        skip "Requires actual card_grant which triggers disbursement logic"
      end
    end

    context "non-primary ledger" do
      it "enforces cannot have event owner at database level" do
        event = create(:event)

        expect {
          ledger = Ledger.new(primary: false, event: event)
          ledger.save(validate: false)
        }.to raise_error(ActiveRecord::StatementInvalid)
      end

      it "enforces cannot have card_grant owner at database level" do
        card_grant = build_stubbed(:card_grant)

        expect {
          ledger = Ledger.new(primary: false, card_grant_id: card_grant.id)
          ledger.save(validate: false)
        }.to raise_error(ActiveRecord::StatementInvalid)
      end

      it "allows non-primary with no owner" do
        ledger = Ledger.new(primary: false)
        ledger.save(validate: false)
        expect(ledger.persisted?).to be true
      end
    end

    context "unique owner constraint" do
      it "enforces that an event can only have one primary ledger" do
        event = create(:event)

        # Create first primary ledger for event
        ledger1 = Ledger.create!(primary: true, event: event)
        expect(ledger1.persisted?).to be true

        # Try to create second primary ledger for same event - should fail
        expect {
          ledger2 = Ledger.new(primary: true, event: event)
          ledger2.save(validate: false)
        }.to raise_error(ActiveRecord::RecordNotUnique)
      end

      it "enforces that a card_grant can only have one primary ledger" do
        # Skip this test for now since card_grant creation triggers complex side effects
        skip "Requires actual card_grant which triggers disbursement logic"
      end
    end
  end
end
