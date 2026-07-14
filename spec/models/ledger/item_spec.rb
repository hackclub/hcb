# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::Item, type: :model do
  include DonationSupport

  describe "associations" do
    it "has many ledger_mappings" do
      item = Ledger::Item.new
      expect(item).to respond_to(:ledger_mappings)
    end

    it "has one primary_mapping" do
      item = Ledger::Item.new
      expect(item).to respond_to(:primary_mapping)
    end

    it "has one primary_ledger through primary_mapping" do
      item = Ledger::Item.new
      expect(item).to respond_to(:primary_ledger)
    end

    describe "primary_ledger association" do
      let(:primary_ledger) do
        # Event automatically creates a primary ledger
        create(:event).ledger
      end
      let(:non_primary_ledger) do
        l = ::Ledger.new(primary: false)
        l.save(validate: false)
        l
      end

      it "returns the ledger from the primary mapping" do
        item = Ledger::Item.new(
          amount_cents: 1000,
          memo: "Test",
          datetime: Time.current
        )
        item.save(validate: false)

        Ledger::Mapping.create!(
          ledger: primary_ledger,
          ledger_item: item,
          on_primary_ledger: true
        )

        expect(item.primary_ledger).to eq(primary_ledger)
      end

      it "returns nil when no primary mapping exists" do
        item = Ledger::Item.new(
          amount_cents: 1000,
          memo: "Test",
          datetime: Time.current
        )
        item.save(validate: false)

        Ledger::Mapping.create!(
          ledger: non_primary_ledger,
          ledger_item: item,
          on_primary_ledger: false
        )

        expect(item.primary_ledger).to be_nil
      end

      it "only returns the primary ledger, not non-primary ledgers" do
        item = Ledger::Item.new(
          amount_cents: 1000,
          memo: "Test",
          datetime: Time.current
        )
        item.save(validate: false)

        Ledger::Mapping.create!(
          ledger: primary_ledger,
          ledger_item: item,
          on_primary_ledger: true
        )
        Ledger::Mapping.create!(
          ledger: non_primary_ledger,
          ledger_item: item,
          on_primary_ledger: false
        )

        expect(item.primary_ledger).to eq(primary_ledger)
      end
    end
  end

  describe "validations" do
    it "requires amount_cents" do
      item = Ledger::Item.new(memo: "Test", datetime: Time.current)
      expect(item).not_to be_valid
      expect(item.errors[:amount_cents]).to include("can't be blank")
    end

    it "requires memo" do
      item = Ledger::Item.new(amount_cents: 1000, datetime: Time.current)
      expect(item).not_to be_valid
      expect(item.errors[:memo]).to include("can't be blank")
    end

    it "requires datetime" do
      item = Ledger::Item.new(amount_cents: 1000, memo: "Test")
      expect(item).not_to be_valid
      expect(item.errors[:datetime]).to include("can't be blank")
    end

    describe "primary_ledger association" do
      it "can be created without a primary_ledger" do
        item = Ledger::Item.new(
          amount_cents: 1000,
          memo: "Test",
          datetime: Time.current
        )
        expect(item).to be_valid
        expect(item.primary_ledger).to be_nil
      end

      it "can have a primary_ledger when mapped" do
        item = create(:ledger_item, :with_primary_ledger)
        expect(item).to be_valid
        expect(item.primary_ledger).to be_present
      end

      it "primary_ledger is accessible through mapping" do
        primary_ledger = create(:event).ledger

        item = Ledger::Item.new(
          amount_cents: 1000,
          memo: "Test",
          datetime: Time.current
        )
        item.save(validate: false)

        Ledger::Mapping.create!(
          ledger: primary_ledger,
          ledger_item: item,
          on_primary_ledger: true
        )

        item.reload
        expect(item).to be_valid
        expect(item.primary_ledger).to eq(primary_ledger)
      end

      # I can't think of a use case for this right now, but in theory there's
      # no reason why we can't support it. Potential use case might be admin
      # ledger audits that includes unmapped (to primary ledger) transactions
      it "can have only non-primary ledger mappings" do
        non_primary_ledger = ::Ledger.new(primary: false)
        non_primary_ledger.save(validate: false)

        item = Ledger::Item.new(
          amount_cents: 1000,
          memo: "Test",
          datetime: Time.current
        )
        item.save!

        Ledger::Mapping.create!(
          ledger: non_primary_ledger,
          ledger_item: item,
          on_primary_ledger: false
        )

        item.reload
        expect(item).to be_valid
        expect(item.primary_ledger).to be_nil
        expect(item.all_ledgers).to contain_exactly(non_primary_ledger)
      end
    end

    describe "one primary mapping constraint" do
      it "allows an item to have exactly one primary mapping" do
        primary_ledger = create(:event).ledger

        item = Ledger::Item.new(
          amount_cents: 1000,
          memo: "Test",
          datetime: Time.current
        )
        item.save(validate: false)

        mapping = Ledger::Mapping.create!(
          ledger: primary_ledger,
          ledger_item: item,
          on_primary_ledger: true
        )

        item.reload
        expect(item.ledger_mappings.where(on_primary_ledger: true).count).to eq(1)
        expect(item.primary_mapping).to eq(mapping)
      end

      it "does not allow an item to have multiple primary mappings" do
        primary_ledger1 = create(:event).ledger
        primary_ledger2 = create(:event).ledger

        item = Ledger::Item.new(
          amount_cents: 1000,
          memo: "Test",
          datetime: Time.current
        )
        item.save(validate: false)

        # Create first primary mapping
        Ledger::Mapping.create!(
          ledger: primary_ledger1,
          ledger_item: item,
          on_primary_ledger: true
        )

        # Try to create second primary mapping - should fail
        mapping2 = Ledger::Mapping.new(
          ledger: primary_ledger2,
          ledger_item: item,
          on_primary_ledger: true
        )

        expect(mapping2).not_to be_valid
        expect(mapping2.errors[:ledger_item_id]).to include("is already mapped on a primary ledger")
      end

      it "allows an item to have one primary mapping and multiple non-primary mappings" do
        primary_ledger = create(:event).ledger

        non_primary_ledger1 = ::Ledger.new(primary: false)
        non_primary_ledger1.save(validate: false)

        non_primary_ledger2 = ::Ledger.new(primary: false)
        non_primary_ledger2.save(validate: false)

        item = Ledger::Item.new(
          amount_cents: 1000,
          memo: "Test",
          datetime: Time.current
        )
        item.save(validate: false)

        # Create primary mapping
        primary_mapping = Ledger::Mapping.create!(
          ledger: primary_ledger,
          ledger_item: item,
          on_primary_ledger: true
        )

        # Create first non-primary mapping
        Ledger::Mapping.create!(
          ledger: non_primary_ledger1,
          ledger_item: item,
          on_primary_ledger: false
        )

        # Create second non-primary mapping
        Ledger::Mapping.create!(
          ledger: non_primary_ledger2,
          ledger_item: item,
          on_primary_ledger: false
        )

        item.reload
        expect(item.ledger_mappings.count).to eq(3)
        expect(item.ledger_mappings.where(on_primary_ledger: true).count).to eq(1)
        expect(item.ledger_mappings.where(on_primary_ledger: false).count).to eq(2)
        expect(item.primary_mapping).to eq(primary_mapping)
      end

      it "enforces one primary mapping at database level" do
        primary_ledger1 = create(:event).ledger
        primary_ledger2 = create(:event).ledger

        item = Ledger::Item.new(
          amount_cents: 1000,
          memo: "Test",
          datetime: Time.current
        )
        item.save(validate: false)

        # Create first primary mapping
        Ledger::Mapping.create!(
          ledger: primary_ledger1,
          ledger_item: item,
          on_primary_ledger: true
        )

        # Try to create second primary mapping with validation bypassed
        # Should fail at database level due to unique index
        expect {
          mapping2 = Ledger::Mapping.new(
            ledger: primary_ledger2,
            ledger_item: item,
            on_primary_ledger: true
          )
          mapping2.save(validate: false)
        }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  describe "#calculate_amount_cents" do
    let(:item) do
      i = Ledger::Item.new(amount_cents: 0, memo: "Test", datetime: Time.current)
      i.save(validate: false)
      i
    end

    it "returns 0 when there are no transactions" do
      expect(item.calculate_amount_cents).to eq(0)
    end

    it "sums canonical transaction amounts" do
      create(:canonical_transaction, amount_cents: -500, ledger_item_id: item.id)
      create(:canonical_transaction, amount_cents: -300, ledger_item_id: item.id)

      expect(item.calculate_amount_cents).to eq(-800)
    end
  end

  describe "#refresh!" do
    it "updates amount_cents from calculate_amount_cents and updates receipt_required from calculate_receipt_required" do
      # The primary ledger's plan requires receipts, so a negative amount makes
      # the item's receipt_required.
      primary_ledger = create(:event).ledger

      item = Ledger::Item.new(amount_cents: 999, memo: "Test", datetime: Time.current)
      item.save(validate: false)

      Ledger::Mapping.create!(
        ledger: primary_ledger,
        ledger_item: item,
        on_primary_ledger: true
      )

      create(:canonical_transaction, amount_cents: -500, ledger_item_id: item.id)

      item.refresh!
      item.reload

      expect(item.amount_cents).to eq(-500)
      expect(item.receipt_required).to eq(true)
    end

    it "overrides the system memo with the custom memo in the memo column" do
      stub_donation_payment_intent_creation
      donation = create(:donation)

      item = Ledger::Item.new(
        amount_cents: 1000,
        memo: "Initial",
        datetime: Time.current,
        linked_object: donation
      )
      item.save(validate: false)

      item.refresh!
      item.reload

      # Without a custom memo, the memo column falls back to the system memo
      expect(item.system_memo).to eq("Donation from #{donation.smart_memo}")
      expect(item.memo).to eq(item.system_memo)

      item.update!(custom_memo: "Custom memo")
      item.refresh!
      item.reload

      expect(item.system_memo).to eq("Donation from #{donation.smart_memo}")
      expect(item.memo).to eq("Custom memo")
    end

    it "normalizes a blank custom memo to nil so the memo falls back to the system memo" do
      stub_donation_payment_intent_creation
      donation = create(:donation)

      item = Ledger::Item.new(
        amount_cents: 1000,
        memo: "Initial",
        datetime: Time.current,
        linked_object: donation
      )
      item.save(validate: false)

      item.update!(custom_memo: "  ")
      item.refresh!
      item.reload

      expect(item.custom_memo).to be_nil
      expect(item.memo).to eq(item.system_memo)

      item.update!(custom_memo: "  Custom memo  ")
      expect(item.custom_memo).to eq("Custom memo")
    end
  end

  describe "account verification detection" do
    # Pins memo/amount/linked_object_type past the refresh! callbacks (which
    # recompute them from canonical transactions these items don't have),
    # mirroring the shared ledger specs. A null linked_object_type marks a raw
    # bank transaction, which is what account-verification micro-deposits are.
    def acctverify_item(memo:, amount_cents:, linked_object_type: nil)
      item = create(:ledger_item)
      item.update_columns(memo:, amount_cents:, linked_object_type:)
      item.reload
    end

    describe "#likely_account_verification_related?" do
      it "is true for a sub-$1 raw bank transaction whose memo names a verification" do
        expect(acctverify_item(memo: "ACCTVERIFY deposit", amount_cents: 12)).to be_likely_account_verification_related
      end

      it "matches the other known memo variants case-insensitively" do
        ["sdv-vrfy", "AMTS: 0.12", "validation", "verify"].each do |memo|
          expect(acctverify_item(memo:, amount_cents: -12)).to be_likely_account_verification_related
        end
      end

      it "is false when the amount is $1 or more" do
        expect(acctverify_item(memo: "ACCTVERIFY deposit", amount_cents: 100)).not_to be_likely_account_verification_related
      end

      it "is false when the transaction has a linked object" do
        expect(acctverify_item(memo: "ACCTVERIFY deposit", amount_cents: 12, linked_object_type: "Invoice")).not_to be_likely_account_verification_related
      end

      it "is false when the memo does not name a verification" do
        expect(acctverify_item(memo: "Coffee", amount_cents: 12)).not_to be_likely_account_verification_related
      end
    end
  end
end
