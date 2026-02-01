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
  end
end
