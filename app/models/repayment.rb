# frozen_string_literal: true

# == Schema Information
#
# Table name: repayments
#
#  id                      :bigint           not null, primary key
#  amount_cents            :integer          not null
#  previous_categories     :jsonb            not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  created_by_id           :bigint
#  disbursement_id         :bigint
#  ledger_item_id          :bigint           not null
#  repaying_ledger_item_id :bigint
#
# Indexes
#
#  index_repayments_on_created_by_id                       (created_by_id)
#  index_repayments_on_disbursement_id                     (disbursement_id)
#  index_repayments_on_disbursement_id_and_ledger_item_id  (disbursement_id,ledger_item_id) UNIQUE
#  index_repayments_on_ledger_item_id                      (ledger_item_id)
#  index_repayments_on_repaying_ledger_item_id             (repaying_ledger_item_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (disbursement_id => disbursements.id)
#  fk_rails_...  (ledger_item_id => ledger_items.id)
#  fk_rails_...  (repaying_ledger_item_id => ledger_items.id)
#
# Check Constraints
#
#  repayments_disbursement_or_repaying_ledger_item  (num_nonnulls(disbursement_id, repaying_ledger_item_id) = 1)
#
# Links a transaction to what repaid it: either a disbursement, where another
# organization pays the expense back, or money that came in on the same
# ledger and was marked as paying it back (e.g. a check from whoever owed it).
#
# Modeled as a join so a transaction can be repaid by several disbursements
# and a disbursement can repay several transactions, but for now each
# repayment covers exactly one transaction in full.
class Repayment < ApplicationRecord
  # Both sides of a repayment on the repaid organization's ledger carry this
  # category: the expense and the money paying it back. Money in under it
  # lowers expenses instead of counting as revenue.
  CATEGORY_SLUG = "repayment"

  # Transfers between organizations go through a repayment transfer instead,
  # and donations and invoices are revenue, not money paid back.
  NON_REPAYING_LINKED_OBJECT_TYPES = ["Disbursement::Outgoing", "Disbursement::Incoming", "Donation", "Invoice"].freeze

  has_paper_trail

  belongs_to :disbursement, optional: true
  belongs_to :repaying_ledger_item, class_name: "Ledger::Item", optional: true, inverse_of: :repaying_repayment
  belongs_to :repaid_ledger_item, class_name: "Ledger::Item", foreign_key: :ledger_item_id, inverse_of: :repayments
  belongs_to :created_by, class_name: "User", optional: true

  # Rejected and errored disbursements never moved money, so they don't count.
  # Repayments by a ledger item have no disbursement to fail.
  scope :not_failed, -> {
    left_joins(:disbursement)
      .where(disbursement_id: nil)
      .or(left_joins(:disbursement).where.not(disbursements: { aasm_state: [:rejected, :errored] }))
  }

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

  # Settled money in on the organization's ledger that could have paid an
  # expense back. Pending items can still change amount, like expenses.
  def self.repaying_ledger_items(event)
    event.ledger.items
         .where(status: :settled)
         .where("ledger_items.amount_cents > 0")
         .where("ledger_items.linked_object_type IS NULL OR ledger_items.linked_object_type NOT IN (?)", NON_REPAYING_LINKED_OBJECT_TYPES)
         .not_likely_account_verification_related
  end

  # Money in that hasn't already been marked as repaying something.
  def self.unused_repaying_ledger_items(event)
    repaying_ledger_items(event).where.not(id: where.not(repaying_ledger_item_id: nil).select(:repaying_ledger_item_id))
  end

  # What a ledger item could be marked as a repayment with: for an unrepaid
  # expense, unused money in of the same amount; for unused money in,
  # unrepaid expenses of the same amount.
  def self.match_candidates(ledger_item)
    event = ledger_item.primary_ledger&.event
    return Ledger::Item.none if event.nil?

    own, others = if ledger_item.amount_cents.negative?
                    [unrepaid_ledger_items(event), unused_repaying_ledger_items(event)]
                  else
                    [unused_repaying_ledger_items(event), unrepaid_ledger_items(event)]
                  end
    return Ledger::Item.none unless own.exists?(ledger_item.id)

    others.where(amount_cents: -ledger_item.amount_cents)
  end

  validates :amount_cents, numericality: { greater_than: 0 }
  # Ledger item amounts can change later (e.g. a partial refund), so these are
  # only checked when the repayment is made.
  validate :repaid_transaction_is_an_expense_of_the_event, on: :create
  validate :repaying_transaction_is_money_in_on_the_same_ledger, on: :create, if: :repaying_ledger_item
  validate :repays_in_full, on: :create
  validate :repaid_transaction_not_already_repaid, on: :create
  validates :repaying_ledger_item, uniqueness: { message: "has already been marked as a repayment" }, allow_nil: true

  # In-memory counterpart to `not_failed`, for preloaded repayments.
  def failed?
    disbursement.present? && (disbursement.rejected? || disbursement.errored?)
  end

  # The organization whose expense was repaid.
  def event
    disbursement&.destination_event || repaying_ledger_item&.primary_ledger&.event
  end

  def repaid_transactions
    [
      *repaid_ledger_item.canonical_transactions.includes(category_mapping: :category),
      *repaid_ledger_item.canonical_pending_transactions.includes(category_mapping: :category)
    ]
  end

  def repaying_transactions
    return [] if repaying_ledger_item.nil?

    [
      *repaying_ledger_item.canonical_transactions.includes(category_mapping: :category),
      *repaying_ledger_item.canonical_pending_transactions.includes(category_mapping: :category)
    ]
  end

  def repaid_category
    repaid_transactions.filter_map { |t| t.category_mapping&.category }.first
  end

  # Remembers each repaid transaction's category (and whether it was set by
  # hand) so rejecting the repayment can put it back.
  def apply_categories!
    # A transfer's incoming side is categorized when it's created, so only a
    # repaying ledger item needs it here.
    transactions = repaid_transactions + repaying_transactions
    update!(previous_categories: transactions.to_h { |t| [snapshot_key(t), category_snapshot(t)] })
    transactions.each do |t|
      TransactionCategoryService.new(model: t).set!(slug: CATEGORY_SLUG, assignment_strategy: "manual")
    end
  end

  # Puts each repaid transaction back to the category it had before, unless
  # someone has recategorized it since.
  def revert_categories!
    (repaid_transactions + repaying_transactions).each do |t|
      mapping = t.category_mapping
      next unless mapping&.category&.slug == CATEGORY_SLUG

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

  def repaid_transaction_is_an_expense_of_the_event
    return if repaid_ledger_item.nil? || event.nil?

    unless Repayment.repayable_ledger_items(event).exists?(repaid_ledger_item.id)
      errors.add(:repaid_ledger_item, "must be a settled expense of #{event.name}")
    end
  end

  # The event comes from the repaying item's ledger, so this also keeps both
  # sides on the same ledger.
  def repaying_transaction_is_money_in_on_the_same_ledger
    return if event.nil?

    unless Repayment.repaying_ledger_items(event).exists?(repaying_ledger_item.id)
      errors.add(:repaying_ledger_item, "must be settled money in on #{event.name}'s ledger")
    end
  end

  def repays_in_full
    repaying_amount_cents = disbursement&.amount || repaying_ledger_item&.amount_cents
    return if repaid_ledger_item.nil? || repaying_amount_cents.nil?

    unless amount_cents == repaying_amount_cents && amount_cents == -repaid_ledger_item.amount_cents
      errors.add(:amount_cents, "must match the full amount of the repaid transaction")
    end
  end

  def repaid_transaction_not_already_repaid
    return if repaid_ledger_item.nil?

    errors.add(:repaid_ledger_item, "has already been repaid") if repaid_ledger_item.repayments.not_failed.where.not(id:).exists?
  end

end
