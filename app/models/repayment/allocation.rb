# frozen_string_literal: true

# == Schema Information
#
# Table name: repayment_allocations
#
#  id                  :bigint           not null, primary key
#  amount_cents        :integer          not null
#  previous_categories :jsonb            not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  ledger_item_id      :bigint           not null
#  repayment_id        :bigint           not null
#
# Indexes
#
#  index_repayment_allocations_on_ledger_item_id                   (ledger_item_id)
#  index_repayment_allocations_on_repayment_id                     (repayment_id)
#  index_repayment_allocations_on_repayment_id_and_ledger_item_id  (repayment_id,ledger_item_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (ledger_item_id => ledger_items.id)
#  fk_rails_...  (repayment_id => repayments.id)
#
# Check Constraints
#
#  repayment_allocations_positive_amount  (amount_cents > 0)
#
# Links a repayment instance to a transaction it repays. The destination
# organization had the expense; the source organization is paying it back.
#
# Each allocation still covers one expense in full. Partial repayment needs
# separate accounting and category-snapshot handling before it can be enabled.
class Repayment
  class Allocation < ApplicationRecord
    belongs_to :repayment, inverse_of: :allocations
    delegate :disbursement, to: :repayment, allow_nil: true
    belongs_to :repaid_ledger_item, class_name: "Ledger::Item", foreign_key: :ledger_item_id, inverse_of: :repayment_allocations

    # Rejected and errored disbursements never moved money, so they don't count.
    scope :not_failed, -> { joins(:repayment).merge(Repayment.not_failed) }

    # Settled expenses on the organization's ledger. Pending ones can still
    # change amount or drop off, so they can't be repaid yet. Transfers between
    # organizations can't be repaid, nor can account-verification micro-deposits,
    # whose amounts are redacted from transparent ledgers.
    def self.repayable_ledger_items(event)
      event.ledger.items
           .where(status: :settled)
           .where("ledger_items.amount_cents < 0")
           .where("ledger_items.linked_object_type IS NULL OR ledger_items.linked_object_type NOT IN (?)", ["Disbursement::Outgoing", "Disbursement::Incoming"])
           .not_likely_account_verification_related
    end

    # Repayable items that no live repayment covers yet.
    def self.unrepaid_ledger_items(event)
      repayable_ledger_items(event).where.not(id: not_failed.select(:ledger_item_id))
    end

    validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
    # Ledger item amounts can change later (e.g. a partial refund), so these are
    # only checked when the repayment is made.
    validate :repaid_transaction_is_an_expense_of_the_destination, on: :create
    validate :repays_in_full, on: :create
    validate :repaid_transaction_not_already_repaid, on: :create

    def repaid_transactions
      [
        *repaid_ledger_item.canonical_transactions.includes(category_mapping: :category),
        *repaid_ledger_item.canonical_pending_transactions.includes(category_mapping: :category)
      ]
    end

    def repaid_category
      repaid_transactions.filter_map { |t| t.category_mapping&.category }.first
    end

    # Remembers each repaid transaction's category (and whether it was set by
    # hand) so rejecting the repayment can put it back.
    def apply_categories!
      transactions = repaid_transactions
      update!(previous_categories: transactions.to_h { |t| [snapshot_key(t), category_snapshot(t)] })
      transactions.each do |t|
        TransactionCategoryService.new(model: t).set!(slug: Repayment::CATEGORY_SLUG, assignment_strategy: "manual")
      end
    end

    # Puts each repaid transaction back to the category it had before, unless
    # someone has recategorized it since.
    def revert_categories!
      repaid_transactions.each do |t|
        mapping = t.category_mapping
        next unless mapping&.category&.slug == Repayment::CATEGORY_SLUG

        previous = previous_categories[snapshot_key(t)]
        if previous.nil?
          mapping.destroy!
        else
          mapping.update!(
            category: TransactionCategory.find_or_create_by!(slug: previous["slug"]),
            assignment_strategy: previous["assignment_strategy"]
          )
        end
      end
    end

    private

    def snapshot_key(transaction)
      "#{transaction.class.name}:#{transaction.id}"
    end

    def category_snapshot(transaction)
      mapping = transaction.category_mapping
      return if mapping.nil?

      { "slug" => mapping.category.slug, "assignment_strategy" => mapping.assignment_strategy }
    end

    def repaid_transaction_is_an_expense_of_the_destination
      return if repaid_ledger_item.nil? || disbursement.nil?

      unless Repayment.repayable_ledger_items(disbursement.destination_event).exists?(repaid_ledger_item.id)
        errors.add(:repaid_ledger_item, "must be a settled expense of #{disbursement.destination_event.name}")
      end
    end

    def repays_in_full
      return if repaid_ledger_item.nil? || disbursement.nil?

      unless amount_cents == -repaid_ledger_item.amount_cents
        errors.add(:amount_cents, "must match the full amount of the repaid transaction")
      end
    end

    def repaid_transaction_not_already_repaid
      return if repaid_ledger_item.nil?

      errors.add(:repaid_ledger_item, "has already been repaid") if repaid_ledger_item.repayment_allocations.not_failed.where.not(id:).exists?
    end

  end

end
