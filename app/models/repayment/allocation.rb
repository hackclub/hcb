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

    has_many :splits, class_name: "TransactionSplit", foreign_key: :repayment_allocation_id, inverse_of: :repayment_allocation, dependent: :destroy

    # Rejected and errored disbursements never moved money, so they don't count.
    scope :not_failed, -> { joins(:repayment).merge(Repayment.not_failed) }

    # Pending and settled expenses on the organization's ledger. Transfers
    # between organizations can't be repaid, nor can account-verification
    # micro-deposits, whose amounts are redacted from transparent ledgers.
    def self.repayable_ledger_items(event)
      event.ledger.items
           .where(status: [:pending, :settled])
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

    # Brings an expense's categories and splits in line with what it costs now.
    # An expense's amount can change after it's repaid (a tip at settlement, a
    # partial refund), and the amount repaid doesn't:
    #
    # - Costs what was repaid: the whole expense is a repayment, with no splits.
    # - Costs more: the repaid part becomes a repayment split and the rest goes
    #   back to the expense's own category.
    # - Costs less: the whole expense is a repayment, and the part of the
    #   payment beyond its cost is split off as an internal transfer.
    #
    # Works from the current state alone, so it's safe to run at any time.
    def self.sync_splits!(ledger_item)
      allocations = ledger_item.repayment_allocations.not_failed.order(:id).to_a
      return if allocations.empty?

      TransactionSplit.where(repayment_allocation: allocations).destroy_all
      cost = [-ledger_item.amount_cents, 0].max

      if cost > allocations.sum(&:amount_cents)
        allocations.each do |allocation|
          allocation.revert_categories!
          allocation.split!(ledger_item, -allocation.amount_cents, Repayment::CATEGORY_SLUG, "Repaid by #{allocation.disbursement.source_event.name}")
        end
      else
        allocations.each do |allocation|
          allocation.apply_categories!
          covered = [allocation.amount_cents, cost].min
          cost -= covered

          payment = allocation.disbursement.incoming_disbursement.ledger_item
          allocation.split!(payment, allocation.amount_cents - covered, "internal-transfer", "Extra beyond the cost of #{ledger_item.memo}") if payment
        end
      end
    end

    # Splits `amount_cents` off the ledger item's transactions under a
    # category, taking only the room each transaction has left so it can't fail.
    def split!(ledger_item, amount_cents, category_slug, memo)
      category = TransactionCategory.find_or_create_by!(slug: category_slug)
      transactions = [*ledger_item.canonical_transactions, *ledger_item.canonical_pending_transactions.unsettled]

      transactions.each do |transaction|
        room = transaction.amount_cents - transaction.splits.sum(:amount_cents)
        part = amount_cents.clamp(*[0, room].sort)
        next if part.zero?

        splits.create!(splittable: transaction, amount_cents: part, category:, memo:)
        amount_cents -= part
      end
    end

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
    # Skips transactions that are already a repayment, so running it again
    # doesn't remember "repayment" as the category to put back.
    def apply_categories!
      transactions = repaid_transactions.reject { |t| t.category_mapping&.category&.slug == Repayment::CATEGORY_SLUG }
      # A transaction settling a pending one we remembered goes back to that
      # category (see revert_categories!), so it needs no entry of its own.
      remembered = transactions.reject { |t| t.try(:canonical_pending_transaction)&.then { |pending| previous_categories.key?(snapshot_key(pending)) } }
      update!(previous_categories: previous_categories.merge(remembered.to_h { |t| [snapshot_key(t), category_snapshot(t)] }))
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

        # A transaction that settled after the repayment has no snapshot of its
        # own; it inherited the category from its pending transaction.
        key = snapshot_key(t)
        key = snapshot_key(t.canonical_pending_transaction) if !previous_categories.key?(key) && t.try(:canonical_pending_transaction)
        previous = previous_categories[key]
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
        errors.add(:repaid_ledger_item, "must be an expense of #{disbursement.destination_event.name}")
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
