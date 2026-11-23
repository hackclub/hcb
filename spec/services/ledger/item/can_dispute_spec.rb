# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::Item::CanDispute do
  let(:item) { create(:ledger_item, :with_primary_ledger) }

  def run(ledger_item)
    described_class.new(ledger_item:).run
  end

  it "refuses an item with no transactions" do
    expect(run(item)).to eq([false, "This is not a valid transaction"])
  end

  context "for a bank transaction" do
    it "permits one posted within the last 90 days" do
      create(:canonical_transaction, amount_cents: -500, date: 10.days.ago, created_at: 10.days.ago, ledger_item_id: item.id)

      expect(run(item.reload)).to eq([true, nil])
    end

    it "refuses money out older than 90 days" do
      create(:canonical_transaction, amount_cents: -500, date: 91.days.ago, created_at: 91.days.ago, ledger_item_id: item.id)

      expect(run(item.reload)).to eq([false, "Bank account transactions older than 90 days can not be disputed."])
    end

    it "permits money in no matter its age" do
      create(:canonical_transaction, amount_cents: 500, date: 91.days.ago, created_at: 91.days.ago, ledger_item_id: item.id)

      expect(run(item.reload)).to eq([true, nil])
    end
  end

  context "for a card charge" do
    let(:event) { create(:event) }
    let(:stripe_card) { create(:stripe_card, :with_stripe_id, event:) }

    def charge(created_at:)
      pending = create(:canonical_pending_transaction, event:, amount_cents: -1000, date: created_at, created_at:, raw_pending_stripe_transaction: create(:raw_pending_stripe_transaction, stripe_card:))

      pending.local_hcb_code.ledger_item.reload
    end

    it "permits one made within the last 90 days" do
      expect(run(charge(created_at: 10.days.ago))).to eq([true, nil])
    end

    it "refuses one older than 90 days" do
      expect(run(charge(created_at: 91.days.ago))).to eq([false, "Card transactions older than 90 days can not be disputed."])
    end

    it "refuses a force capture, which was never authorized" do
      item = charge(created_at: 10.days.ago)
      item.linked_object.update!(raw_pending_stripe_transaction: nil)

      expect(run(item.reload)).to eq([false, "Can not dispute this type of transaction"])
    end
  end

  # The checks below only read the item's type and counts, so nothing needs saving.
  it "permits a donation no matter its age" do
    item = build(:ledger_item, linked_object_type: "Donation", cpt_count: 1, datetime: 2.years.ago)

    expect(run(item)).to eq([true, nil])
  end

  it "refuses every other kind of transaction" do
    item = build(:ledger_item, linked_object_type: "AchTransfer", ct_count: 1)

    expect(run(item)).to eq([false, "Can not dispute this type of transaction"])
  end
end
