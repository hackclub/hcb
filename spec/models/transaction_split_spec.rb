# frozen_string_literal: true

require "rails_helper"

RSpec.describe TransactionSplit do
  let(:event) { create(:event) }
  let(:repayment) { TransactionCategory.find_or_create_by!(slug: "repayment") }

  # Factory transactions get an `HCB-000-<id>` code, and settled and pending
  # ones have separate id sequences: a pair that landed on the same id would be
  # grouped together. Pending ones here take an id no settled one can share.
  def create_pending(**attrs)
    create(:canonical_pending_transaction, id: [CanonicalTransaction.maximum(:id).to_i, CanonicalPendingTransaction.maximum(:id).to_i].max + 1_000, event:, **attrs)
  end

  it "carves parts out of a transaction with their own memo and category" do
    transaction = create(:canonical_transaction, amount_cents: -100_00, memo: "PIZZA PLACE")
    transaction.splits.create!(amount_cents: -60_00, memo: "Repaid", category: repayment)
    transaction.splits.create!(amount_cents: -15_00)

    expect(transaction.splits.map { |s| [s.amount_cents, s.memo, s.category&.slug] }).to eq([[-60_00, "Repaid", "repayment"], [-15_00, "PIZZA PLACE", nil]])
  end

  it "rejects parts that are zero, the wrong sign, or more than is left" do
    transaction = create_pending(amount_cents: -100_00)
    transaction.splits.create!(amount_cents: -60_00)

    [0, 10_00, -40_01].each do |amount_cents|
      expect(transaction.splits.build(amount_cents:)).not_to be_valid
    end
    expect(transaction.splits.build(amount_cents: -40_00)).to be_valid
  end

  it "locks a split's category once it's made" do
    transaction = create(:canonical_transaction, amount_cents: -100_00)
    split = transaction.splits.create!(amount_cents: -60_00, category: repayment)

    expect { split.update!(category: TransactionCategory.find_or_create_by!(slug: "rent")) }.to raise_error(ActiveRecord::ReadonlyAttributeError)
  end

  describe "settling a pending transaction" do
    def settle(pending_cents:, split_cents:, settled_cents:)
      pending = create_pending(amount_cents: pending_cents)
      pending.splits.create!(amount_cents: split_cents, memo: "Repaid", category: repayment)
      settled = create(:canonical_transaction, amount_cents: settled_cents, event:)
      CanonicalPendingTransactionService::Settle.new(canonical_transaction: settled, canonical_pending_transaction: pending).run!
      [pending, settled]
    end

    it "keeps a half-repaid split fixed when the cost goes up, so the rest absorbs it" do
      _, settled = settle(pending_cents: -100_00, split_cents: -50_00, settled_cents: -120_00)

      expect(settled.splits.map { |s| [s.amount_cents, s[:memo], s.category] }).to eq([[-50_00, "Repaid", repayment]])
    end

    it "leaves an unrepaid rest when a fully repaid transaction goes up in cost" do
      _, settled = settle(pending_cents: -100_00, split_cents: -100_00, settled_cents: -120_00)

      expect(settled.splits.sum(:amount_cents)).to eq(-100_00)
    end

    it "cuts the split down to fit when the cost goes down" do
      _, settled = settle(pending_cents: -100_00, split_cents: -100_00, settled_cents: -80_00)

      expect(settled.splits.map(&:amount_cents)).to eq([-80_00])
    end

    it "doesn't copy the splits again for a second capture of the same charge" do
      pending, = settle(pending_cents: -100_00, split_cents: -50_00, settled_cents: -90_00)
      capture = create(:canonical_transaction, amount_cents: -10_00, event:)
      CanonicalPendingTransactionService::Settle.new(canonical_transaction: capture, canonical_pending_transaction: pending).run!

      expect(capture.splits).to be_empty
    end
  end

  it "shows a transaction's pending splits until it settles, then its settled ones" do
    pending = create_pending(amount_cents: -100_00)
    pending.splits.create!(amount_cents: -60_00)
    hcb_code = pending.local_hcb_code
    expect(hcb_code.splits.map(&:splittable)).to eq([pending])

    settled = create(:canonical_transaction, amount_cents: -100_00, event:)
    settled.update_column(:hcb_code, hcb_code.hcb_code)
    settled.splits.create!(amount_cents: -60_00)
    expect(HcbCode.find(hcb_code.id).splits.map(&:splittable)).to eq([settled])
  end
end
