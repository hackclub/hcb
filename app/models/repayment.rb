# frozen_string_literal: true

# Links a disbursement to a transaction it repays. The destination
# organization had the expense; the source organization is paying it back.
#
# Modeled as a join so a transaction can be repaid by several disbursements
# and a disbursement can repay several transactions, but for now each
# repayment covers exactly one transaction in full.
# == Schema Information
#
# Table name: repayments
#
#  id                     :bigint           not null, primary key
#  amount_cents           :integer          not null
#  previous_category_slug :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  disbursement_id        :bigint           not null
#  ledger_item_id         :bigint           not null
#
# Indexes
#
#  index_repayments_on_disbursement_id                     (disbursement_id)
#  index_repayments_on_disbursement_id_and_ledger_item_id  (disbursement_id,ledger_item_id) UNIQUE
#  index_repayments_on_ledger_item_id                      (ledger_item_id)
#
# Foreign Keys
#
#  fk_rails_...  (disbursement_id => disbursements.id)
#  fk_rails_...  (ledger_item_id => ledger_items.id)
#
class Repayment < ApplicationRecord
  belongs_to :disbursement
  belongs_to :repaid_ledger_item, class_name: "Ledger::Item", foreign_key: :ledger_item_id, inverse_of: :repayments

  # Rejected and errored disbursements never moved money, so they don't count.
  scope :active, -> { joins(:disbursement).where.not(disbursements: { aasm_state: [:rejected, :errored] }) }

  # Pending or settled expenses on the organization's ledger. Transfers
  # between organizations can't be repaid.
  def self.repayable_ledger_items(event)
    event.ledger.items
         .where(status: [:pending, :settled])
         .where("ledger_items.amount_cents < 0")
         .where("ledger_items.linked_object_type IS NULL OR ledger_items.linked_object_type NOT IN (?)", ["Disbursement::Outgoing", "Disbursement::Incoming"])
  end

  validates :amount_cents, numericality: { greater_than: 0 }
  validate :repaid_transaction_is_an_expense_of_the_destination
  validate :repays_in_full
  validate :repaid_transaction_not_already_repaid, on: :create

  def repaid_transactions
    [*repaid_ledger_item.canonical_transactions.includes(:category), *repaid_ledger_item.canonical_pending_transactions.includes(:category)]
  end

  def repaid_category
    repaid_transactions.filter_map(&:category).first
  end

  def apply_categories!
    update!(previous_category_slug: repaid_category&.slug)
    repaid_transactions.each do |t|
      TransactionCategoryService.new(model: t).set!(slug: "repayment", assignment_strategy: "manual")
    end
  end

  # Puts the repaid transaction back to the category it had before, unless
  # someone has recategorized it since.
  def revert_categories!
    repaid_transactions.each do |t|
      next unless t.category&.slug == "repayment"

      TransactionCategoryService.new(model: t).set!(slug: previous_category_slug, assignment_strategy: "manual")
    end
  end

  private

  def repaid_transaction_is_an_expense_of_the_destination
    return if repaid_ledger_item.nil? || disbursement.nil?

    unless Repayment.repayable_ledger_items(disbursement.destination_event).exists?(repaid_ledger_item.id)
      errors.add(:repaid_ledger_item, "must be an expense of #{disbursement.destination_event.name}")
    end
  end

  def repays_in_full
    return if repaid_ledger_item.nil? || disbursement.nil?

    unless amount_cents == disbursement.amount && amount_cents == -repaid_ledger_item.amount_cents
      errors.add(:amount_cents, "must match the full amount of the repaid transaction")
    end
  end

  def repaid_transaction_not_already_repaid
    return if repaid_ledger_item.nil?

    errors.add(:repaid_ledger_item, "has already been repaid") if repaid_ledger_item.repayments.active.where.not(id:).exists?
  end

end
