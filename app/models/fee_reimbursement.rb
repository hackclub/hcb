# frozen_string_literal: true

# == Schema Information
#
# Table name: fee_reimbursements
#
#  id               :bigint           not null, primary key
#  amount           :bigint
#  processed_at     :datetime
#  transaction_memo :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  stripe_topup_id  :bigint
#
# Indexes
#
#  index_fee_reimbursements_on_stripe_topup_id   (stripe_topup_id)
#  index_fee_reimbursements_on_transaction_memo  (transaction_memo) UNIQUE
#
class FeeReimbursement < ApplicationRecord
  has_paper_trail

  has_one :invoice, required: false
  has_one :donation, required: false
  has_one :t_transaction, class_name: "Transaction", inverse_of: :fee_reimbursement

  belongs_to :stripe_topup, optional: true

  before_create :default_values

  validates_length_of :transaction_memo, maximum: 30
  validates_uniqueness_of :transaction_memo

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
