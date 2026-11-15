# frozen_string_literal: true

# One instance of paying back expenses, funded by one disbursement.
# == Schema Information
#
# Table name: repayments
#
#  id              :bigint           not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  disbursement_id :bigint           not null
#
# Indexes
#
#  index_repayments_on_disbursement_id  (disbursement_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (disbursement_id => disbursements.id)
#
class Repayment < ApplicationRecord
  # Both sides on the recipient's ledger reduce expenses instead of counting
  # the incoming repayment as revenue.
  CATEGORY_SLUG = "repayment"

  belongs_to :disbursement, inverse_of: :repayment
  has_many :allocations, class_name: "Repayment::Allocation", inverse_of: :repayment, dependent: :destroy, autosave: true
  has_many :repaid_ledger_items, through: :allocations

  scope :not_failed, -> { joins(:disbursement).where.not(disbursements: { aasm_state: [:rejected, :errored] }) }

  validates :disbursement_id, uniqueness: true
  validates :allocations, presence: true
  validate :disbursement_is_a_repayment
  validate :ledger_items_are_unique

  def self.repayable_ledger_items(event) = Allocation.repayable_ledger_items(event)
  def self.unrepaid_ledger_items(event) = Allocation.unrepaid_ledger_items(event)
  def self.unrepaid_cents(ledger_item) = Allocation.unrepaid_cents(ledger_item)

  # Undoes what the repayment did to the expenses it repaid, for when it's
  # rejected or errors.
  def revert_categories!
    allocations.each { |allocation| Allocation.sync_splits!(allocation.repaid_ledger_item, excluding: [allocation]) }
  end

  # Called when a transaction's amount changes: re-syncs the expenses it
  # touches, whether it's a repaid expense or the payment repaying them.
  def self.sync_splits!(ledger_item)
    items = [ledger_item]
    items += ledger_item.linked_object.disbursement.repaid_ledger_items if ledger_item.linked_object_type == "Disbursement::Incoming"
    items.each { |item| Allocation.sync_splits!(item) }
  end

  private

  # The disbursement checks that the allocations add up to its amount.
  def disbursement_is_a_repayment
    errors.add(:disbursement, "must be a repayment") unless disbursement.nil? || disbursement.transfer_type_repayment?
  end

  def ledger_items_are_unique
    ids = allocations.reject(&:marked_for_destruction?).map(&:ledger_item_id)
    errors.add(:allocations, "must include each expense only once") if ids.uniq.size != ids.size
  end

end
