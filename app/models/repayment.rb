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
  validate :allocations_match_disbursement
  validate :ledger_items_are_unique

  def self.repayable_ledger_items(event) = Allocation.repayable_ledger_items(event)
  def self.unrepaid_ledger_items(event) = Allocation.unrepaid_ledger_items(event)

  def revert_categories!
    allocations.each(&:revert_categories!)
  end

  private

  def allocations_match_disbursement
    return unless disbursement

    errors.add(:disbursement, "must be a repayment") unless disbursement.transfer_type_repayment?
    unless allocations.reject(&:marked_for_destruction?).sum { |allocation| allocation.amount_cents.to_i } == disbursement.amount
      errors.add(:allocations, "must match the disbursement amount")
    end
  end

  def ledger_items_are_unique
    ids = allocations.reject(&:marked_for_destruction?).map(&:ledger_item_id)
    errors.add(:allocations, "must include each expense only once") if ids.uniq.size != ids.size
  end

end
