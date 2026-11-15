# frozen_string_literal: true

require "rails_helper"

RSpec.describe Repayment, type: :model do
  let(:event) { create(:event) }
  let(:expense) { create(:canonical_transaction, event:, amount_cents: -100_00, memo: "Pizza", category_slug: "food-fun") }
  let(:income) { create(:canonical_transaction, event:, amount_cents: 100_00, memo: "Check from Sam") }
  let(:member) { create(:organizer_position, event:, role: :member).user }

  def repayment_by(income_ct, expense_ct = expense, amount_cents: 100_00)
    Repayment.new(repaying_ledger_item: income_ct.ledger_item.reload, created_by: member).tap do |r|
      r.allocations.build(repaid_ledger_item: expense_ct.ledger_item.reload, amount_cents:)
    end
  end

  def repayment_by_transfer(expense_ct, disbursement)
    Repayment.new(disbursement:).tap { |r| r.allocations.build(repaid_ledger_item: expense_ct.ledger_item, amount_cents: 100_00) }
  end

  def category_of(ct)
    ct.reload.category_mapping&.category&.slug
  end

  describe "repaid by a ledger item" do
    it "is valid for money in of the same amount on the same ledger" do
      expect(repayment_by(income)).to be_valid
    end

    it "categorizes both sides as a repayment" do
      repayment = repayment_by(income)
      repayment.save!
      repayment.allocations.each(&:apply_categories!)

      expect(category_of(expense)).to eq(Repayment::CATEGORY_SLUG)
      expect(category_of(income)).to eq(Repayment::CATEGORY_SLUG)
    end

    it "rejects a different amount" do
      smaller = create(:canonical_transaction, event:, amount_cents: 50_00)

      repayment = repayment_by(smaller, amount_cents: 50_00)

      expect(repayment).not_to be_valid
      expect(repayment.errors[:"allocations.amount_cents"]).to include("must match the full amount of the repaid transaction")
    end

    it "rejects money in on another organization's ledger" do
      elsewhere = create(:canonical_transaction, event: create(:event), amount_cents: 100_00)

      repayment = repayment_by(elsewhere)

      expect(repayment).not_to be_valid
      expect(repayment.errors[:"allocations.repaid_ledger_item"]).to be_present
    end

    it "accepts a check deposit" do
      income.ledger_item.update_columns(linked_object_type: "CheckDeposit", linked_object_id: 1)

      expect(repayment_by(income)).to be_valid
    end

    it "rejects revenue, refunds and fee credits" do
      %w[Donation Invoice CardCharge BankFee AchTransfer].each do |type|
        revenue = create(:canonical_transaction, event:, amount_cents: 100_00)
        revenue.ledger_item.update_columns(linked_object_type: type, linked_object_id: 1)

        repayment = repayment_by(revenue)

        expect(repayment).not_to be_valid
        expect(repayment.errors[:repaying_ledger_item]).to be_present
      end
    end

    it "rejects money in that already repaid another expense" do
      repayment_by(income).save!
      other_expense = create(:canonical_transaction, event:, amount_cents: -100_00)

      repayment = repayment_by(income, other_expense)

      expect(repayment).not_to be_valid
      expect(repayment.errors[:repaying_ledger_item]).to include("has already been marked as a repayment")
    end

    it "rejects an expense that's already been repaid" do
      repayment_by(income).save!
      other_income = create(:canonical_transaction, event:, amount_cents: 100_00)

      repayment = repayment_by(other_income)

      expect(repayment).not_to be_valid
      expect(repayment.errors[:"allocations.repaid_ledger_item"]).to include("has already been repaid")
    end

    it "rejects an expense already repaid by a transfer" do
      repayment_by_transfer(expense, create(:disbursement, event:)).save!(validate: false)

      expect(repayment_by(income)).not_to be_valid
    end
  end

  describe ".match_candidates" do
    it "matches an expense with unused income of the same amount" do
      income
      create(:canonical_transaction, event:, amount_cents: 50_00)
      used = create(:canonical_transaction, event:, amount_cents: 100_00)
      repayment_by(used, create(:canonical_transaction, event:, amount_cents: -100_00)).save!

      expect(Repayment.match_candidates(expense.ledger_item.reload, member)).to contain_exactly(income.ledger_item)
    end

    it "matches income with unrepaid expenses of up to its amount" do
      expense
      smaller = create(:canonical_transaction, event:, amount_cents: -50_00)
      create(:canonical_transaction, event:, amount_cents: -150_00)

      expect(Repayment.match_candidates(income.ledger_item.reload, member)).to contain_exactly(expense.ledger_item, smaller.ledger_item)
    end

    it "leaves out pending expenses" do
      expense.ledger_item.update_columns(status: "pending")

      expect(described_class.match_candidates(income.ledger_item, member)).to be_empty
      expect(described_class.match_candidates(expense.ledger_item, member)).to be_empty
    end

    it "matches nothing once the transaction is already part of a repayment" do
      repayment_by(income).save!
      create(:canonical_transaction, event:, amount_cents: -100_00)

      expect(Repayment.match_candidates(income.ledger_item.reload, member)).to be_empty
    end
  end

  describe ".not_failed" do
    it "includes repayments by a ledger item and excludes failed transfers" do
      by_income = repayment_by(income).tap(&:save!)
      rejected_expense = create(:canonical_transaction, event:, amount_cents: -100_00)
      rejected = repayment_by_transfer(rejected_expense, create(:disbursement, :rejected, event:))
      rejected.save!(validate: false)

      expect(Repayment.not_failed).to include(by_income)
      expect(Repayment.not_failed).not_to include(rejected)
    end
  end

  describe "database constraint" do
    it "requires exactly one of a disbursement or a repaying ledger item" do
      neither = Repayment.new
      both = repayment_by(income).tap { |r| r.disbursement = create(:disbursement, event:) }

      expect(neither).not_to be_valid
      expect(both).not_to be_valid
      expect { neither.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid, /repayments_disbursement_or_repaying_ledger_item/)
      expect { both.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid, /repayments_disbursement_or_repaying_ledger_item/)
    end
  end
end
