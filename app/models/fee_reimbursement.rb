# frozen_string_literal: true

# == Schema Information
#
# Table name: fee_reimbursements
#
#  id                         :bigint           not null, primary key
#  amount                     :bigint
#  processed_at               :datetime
#  transaction_memo           :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  fee_reimbursement_group_id :bigint
#  stripe_topup_id            :bigint
#
# Indexes
#
#  index_fee_reimbursements_on_fee_reimbursement_group_id  (fee_reimbursement_group_id)
#  index_fee_reimbursements_on_stripe_topup_id             (stripe_topup_id)
#  index_fee_reimbursements_on_transaction_memo            (transaction_memo) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (fee_reimbursement_group_id => fee_reimbursement_groups.id)
#
class FeeReimbursement < ApplicationRecord
  has_paper_trail

  has_one :invoice, required: false
  has_one :donation, required: false
  has_one :t_transaction, class_name: "Transaction", inverse_of: :fee_reimbursement

  belongs_to :stripe_topup, optional: true
  # The week whose HCB code this reimbursement's top-up is made under. Set once (see #assign_fee_reimbursement_group!) and never reassigned; nil for a zero-amount reimbursement, which makes no top-up
  belongs_to :fee_reimbursement_group, optional: true

  before_create :default_values
  after_create_commit { safely { assign_fee_reimbursement_group! } }

  validates_length_of :transaction_memo, maximum: 30
  validates_uniqueness_of :transaction_memo
  validate :fee_reimbursement_group_not_reassigned

  scope :unprocessed, -> { includes(:t_transaction).where(processed_at: nil, transactions: { fee_reimbursement_id: nil }) }
  scope :pending, -> { includes(:t_transaction).where.not(processed_at: nil).where(transactions: { fee_reimbursement_id: nil }) }
  scope :completed, -> { includes(:t_transaction).where.not(transactions: { fee_reimbursement_id: nil }) }

  def unprocessed?
    processed_at.nil? && t_transaction.nil?
  end

  def pending?
    !processed_at.nil?
  end

  def completed?
    canonical_transaction.present?
  end

  def status
    return "completed" if completed?
    return "pending" if pending?

    "unprocessed"
  end

  def status_color
    return "success" if completed?
    return "info" if pending?

    "error"
  end

  def event
    if donation
      return donation.event
    else
      return invoice.try(:event)
    end
  end

  def payout
    if donation
      return donation.payout
    else
      return invoice.try(:payout)
    end
  end

  def transaction_display_name
    if donation
      return "Fee refund for #{donation.anonymous? ? "anonymous donation" : "donation from #{donation.name(show_anonymous: true)}"}"
    else
      return "Fee refund for invoice to #{invoice.sponsor.name}"
    end
  end

  def process
    processed_at = DateTime.now
  end

  def transfer_amount
    [self.amount, 100].max
  end

  def default_values
    if invoice
      self.transaction_memo ||= "HCB-#{invoice.local_hcb_code.short_code}"
      self.amount ||= invoice.payout_creation_balance_stripe_fee
    elsif donation
      self.transaction_memo ||= "HCB-#{donation.local_hcb_code.short_code}"
      self.amount ||= donation.payout_creation_balance_stripe_fee
    end
  end

  # Groups an unprocessed reimbursement into the ISO week it was created in, so
  # its top-up is made under that week's HCB code. A processed one was already
  # topped up under some HCB code, so this never groups it (see
  # Maintenance::BackfillFeeReimbursementGroupsTask). A zero-amount one makes no
  # top-up and stays ungrouped. Idempotent, so the nightly job can also call it
  # for one that wasn't grouped on create.
  def assign_fee_reimbursement_group!
    return if fee_reimbursement_group.present? || !unprocessed? || amount.to_i.zero?

    update!(fee_reimbursement_group: FeeReimbursementGroup.find_or_create_by!(slug: created_at.strftime(FeeReimbursementGroup::WEEK_FORMAT)))
  end

  # The group is the HCB code the top-up is made under, so once set it can't be
  # reassigned.
  def fee_reimbursement_group_not_reassigned
    return unless fee_reimbursement_group_id_changed? && fee_reimbursement_group_id_was.present?

    errors.add(:fee_reimbursement_group, "can't be changed once set")
  end

  def admin_dropdown_description
    "#{ApplicationController.helpers.render_money self.amount} - #{self.transaction_memo} (#{self.event.name})"
  end

  # this needs to exist for the case where amount of reimbursement is less than $1 and we need to do fee weirdness
  def calculate_fee_amount
    if amount < 100
      if invoice.present?
        return (amount * self.invoice.event.revenue_fee) + (100 - amount)
      else
        return (amount * self.donation.event.revenue_fee) + (100 - amount)
      end
    else
      if invoice.present?
        return amount * self.invoice.event.revenue_fee
      else
        return amount * self.donation.event.revenue_fee
      end
    end
  end

  def canonical_transaction
    @canonical_transaction ||= event.canonical_transactions.where("memo ilike ? and date >= ?", "#{sanitize_sql_like(transaction_memo)}%", created_at - 1.day).first
  end

end
