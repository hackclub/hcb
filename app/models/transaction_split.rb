# frozen_string_literal: true

# A fixed part carved out of a pending or settled transaction with its own memo
# and category, e.g. the portion of an expense that another organization
# repaid. Whatever the splits don't cover stays with the transaction itself. A
# split without a category is reported under its transaction's category.
# Categories are set by the system, not chosen by users, and a split's category
# is locked once it's made: the part a repayment covers stays a repayment.
#
# A pending transaction's splits are copied to the transaction that settles it
# (see CanonicalPendingTransactionService::Settle).
# == Schema Information
#
# Table name: transaction_splits
#
#  id                      :bigint           not null, primary key
#  amount_cents            :integer          not null
#  memo                    :text
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  repayment_allocation_id :bigint
#  splittable_id           :bigint           not null
#  splittable_type         :string           not null
#  transaction_category_id :bigint
#
# Indexes
#
#  index_transaction_splits_on_repayment_allocation_id  (repayment_allocation_id)
#  index_transaction_splits_on_splittable               (splittable_type,splittable_id)
#  index_transaction_splits_on_transaction_category_id  (transaction_category_id)
#
# Foreign Keys
#
#  fk_rails_...  (transaction_category_id => transaction_categories.id)
#
class TransactionSplit < ApplicationRecord
  belongs_to :splittable, polymorphic: true
  # Set on splits a repayment made, which it replaces as amounts change (see
  # Repayment::Allocation.sync_splits!).
  belongs_to :repayment_allocation, class_name: "Repayment::Allocation", optional: true, inverse_of: :splits
  belongs_to :category, class_name: "TransactionCategory", foreign_key: :transaction_category_id, inverse_of: false, optional: true

  attr_readonly :transaction_category_id

  validates :splittable_type, inclusion: { in: %w[CanonicalTransaction CanonicalPendingTransaction] }
  validates :amount_cents, numericality: { other_than: 0 }
  validate :fits_within_transaction, if: :amount_cents_changed?

  # Lets the statement of activity list a split as a line of its own
  delegate :hcb_code, :local_hcb_code, :event, to: :splittable

  def memo
    super.presence || splittable.memo
  end

  private

  def fits_within_transaction
    return if splittable.nil? || amount_cents.to_i.zero?

    total = splittable.amount_cents
    split = splittable.splits.where.not(id:).sum(:amount_cents) + amount_cents
    unless amount_cents.positive? == total.positive? && split.abs <= total.abs
      errors.add(:amount_cents, "can't take the transaction's splits past its amount")
    end
  end

end
