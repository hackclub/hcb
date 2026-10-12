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
#  id              :bigint           not null, primary key
#  amount_cents    :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  disbursement_id :bigint           not null
#  hcb_code_id     :bigint           not null
#
# Indexes
#
#  index_repayments_on_disbursement_id                  (disbursement_id)
#  index_repayments_on_disbursement_id_and_hcb_code_id  (disbursement_id,hcb_code_id) UNIQUE
#  index_repayments_on_hcb_code_id                      (hcb_code_id)
#
# Foreign Keys
#
#  fk_rails_...  (disbursement_id => disbursements.id)
#  fk_rails_...  (hcb_code_id => hcb_codes.id)
#
class Repayment < ApplicationRecord
  belongs_to :disbursement
  belongs_to :repaid_hcb_code, class_name: "HcbCode", foreign_key: :hcb_code_id, inverse_of: :repayments

  # Rejected and errored disbursements never moved money, so they don't count.
  scope :active, -> { joins(:disbursement).where.not(disbursements: { aasm_state: [:rejected, :errored] }) }

  validates :amount_cents, numericality: { greater_than: 0 }
  validate :repaid_transaction_is_an_expense_of_the_destination
  validate :repays_in_full
  validate :repaid_transaction_not_already_repaid, on: :create

  # The destination's side of the repaid transaction.
  def repaid_transactions
    repaid_hcb_code.categorizable_transactions_for(disbursement.destination_event)
  end

  def repaid_category
    repaid_transactions.filter_map(&:category).first
  end

  def apply_categories!
    repaid_transactions.each do |t|
      TransactionCategoryService.new(model: t).set!(slug: "repayment", assignment_strategy: "manual")
    end
  end

  # Puts the repaid transaction back to the category it had before, which is
  # what the source side of the disbursement was given.
  def revert_categories!
    repaid_transactions.each do |t|
      TransactionCategoryService.new(model: t).set!(slug: disbursement.source_transaction_category&.slug, assignment_strategy: "manual")
    end
  end

  private

  def repaid_transaction_is_an_expense_of_the_destination
    return if repaid_hcb_code.nil? || disbursement.nil?

    unless repaid_transactions.any? && !repaid_hcb_code.outgoing_disbursement? && !repaid_hcb_code.incoming_disbursement? && repaid_hcb_code.amount_cents.negative?
      errors.add(:repaid_hcb_code, "must be an expense of #{disbursement.destination_event.name}")
    end
  end

  def repays_in_full
    return if repaid_hcb_code.nil? || disbursement.nil?

    unless amount_cents == disbursement.amount && amount_cents == -repaid_hcb_code.amount_cents
      errors.add(:amount_cents, "must match the full amount of the repaid transaction")
    end
  end

  def repaid_transaction_not_already_repaid
    return if repaid_hcb_code.nil?

    errors.add(:repaid_hcb_code, "has already been repaid") if repaid_hcb_code.repayments.active.where.not(id:).exists?
  end

end
