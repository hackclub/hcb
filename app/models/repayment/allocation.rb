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
# Links a repayment instance to a transaction it repays: an expense of the
# repayment's organization.
#
# Each allocation still covers one expense in full. Partial repayment needs
# separate accounting and category-snapshot handling before it can be enabled.
class Repayment
  class Allocation < ApplicationRecord
    belongs_to :repayment, inverse_of: :allocations
    delegate :disbursement, :event, to: :repayment, allow_nil: true
    belongs_to :repaid_ledger_item, class_name: "Ledger::Item", foreign_key: :ledger_item_id, inverse_of: :repayment_allocations

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
    validate :repaid_transaction_is_an_expense_of_the_event, on: :create
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

    # The repaid transactions, plus the money in that repaid them when the
    # repayment was marked between two transactions rather than transferred.
    def categorized_transactions
      repaid_transactions + repayment.repaying_transactions
    end

    # Remembers each transaction's category (and whether it was set by hand)
    # so undoing the repayment can put it back.
    #
    # With recategorize_sender, the sending side of a transfer marked as the
    # repayment takes on the expense's category, as it would have had it been
    # sent as a repayment transfer.
    def apply_categories!(recategorize_sender: false)
      slugs = categorized_transactions.index_with { |t| Repayment::CATEGORY_SLUG }
      expense_slug = repaid_category&.slug
      sender = recategorize_sender && expense_slug ? repayment.sender_transactions : []
      sender.each { |t| slugs[t] = expense_slug }

      update!(previous_categories: slugs.to_h { |t, slug|
        snapshot = category_snapshot(t)
        # The sender's side isn't in the repayment category, so remember what it was set to.
        snapshot = (snapshot || {}).merge("set_to" => slug) if sender.include?(t)
        [snapshot_key(t), snapshot]
      })
      slugs.each do |t, slug|
        TransactionCategoryService.new(model: t).set!(slug:, assignment_strategy: "manual")
      end
    end

    # Puts each transaction back to the category it had before, unless
    # someone has recategorized it since.
    def revert_categories!
      own = categorized_transactions
      (own + repayment.sender_transactions).each do |t|
        # A transaction that settled after the repayment has no snapshot of its
        # own; it inherited the category from its pending transaction.
        key = snapshot_key(t)
        key = snapshot_key(t.canonical_pending_transaction) if !previous_categories.key?(key) && t.try(:canonical_pending_transaction)
        previous = previous_categories[key]

        # The sender's side is only touched if it was recategorized.
        set_to = previous&.dig("set_to") || (Repayment::CATEGORY_SLUG if own.include?(t))
        mapping = t.category_mapping
        next unless set_to && mapping&.category&.slug == set_to

        if previous&.dig("slug").nil?
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

    def repaid_transaction_is_an_expense_of_the_event
      return if repaid_ledger_item.nil? || event.nil?

      unless Repayment.repayable_ledger_items(event).exists?(repaid_ledger_item.id)
        errors.add(:repaid_ledger_item, "must be an expense of #{event.name}")
      end
    end

    def repays_in_full
      return if repaid_ledger_item.nil? || event.nil?

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
