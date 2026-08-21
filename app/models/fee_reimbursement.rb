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
  has_one :raw_pending_fee_reimbursement_transaction

  belongs_to :stripe_topup, optional: true

  before_create :default_values

  validates_length_of :transaction_memo, maximum: 30
  validates_uniqueness_of :transaction_memo

  scope :unprocessed, -> { where(processed_at: nil) }
  scope :pending, -> { includes(:t_transaction).where.not(processed_at: nil).where(transactions: { fee_reimbursement_id: nil }) }
  scope :completed, -> { includes(:t_transaction).where.not(transactions: { fee_reimbursement_id: nil }) }

  # `pending` above joins against the legacy (pre-2021) `transactions` table,
  # which nothing writes to anymore — `transactions.fee_reimbursement_id` is
  # always nil, so `pending` never actually excludes anything and grows
  # forever. This scope is what the nightly backstop actually needs: reimbursements
  # that have been processed (topped up) but still lack the modern
  # RawPendingFeeReimbursementTransaction/CPT, so it shrinks as the backfill catches up.
  scope :missing_pending_transaction, -> { where.not(processed_at: nil).where.missing(:raw_pending_fee_reimbursement_transaction) }

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

  # Has this reimbursement's OWN Stripe top-up already posted as a real,
  # settled bank transaction? NOTE this is deliberately separate from
  # #canonical_transaction above, which checks something else entirely: it's
  # scoped to the *org's* event and matched on the *invoice/donation's* short
  # code (`transaction_memo`), because it's asking whether the underlying
  # invoice/donation payout settled. The reimbursement's own top-up settles
  # under Hack Club Bank (see OUTGOING_FEE_REIMBURSEMENT_CODE), grouped by
  # week, under a *different* short code — so it needs its own lookup.
  #
  # Matched two ways:
  # 1. By the weekly HCB-900-<week> short code embedded in the topup's
  #    statement descriptor (Nightly#local_hcb_code, since 5c932154). This is
  #    reliable regardless of which ISO week the transaction actually clears
  #    in — bank/ACH settlement can land a few business days after
  #    `processed_at`, crossing into the following week.
  # 2. Falling back to a week + amount match for reimbursements processed
  #    before short codes were embedded (pre-2025-05-18), where the settled
  #    memo ("STRIPE FEE REIMBU" / "HCKCLB FEE REIMBU") carries no code to
  #    match on at all — see
  #    TransactionGroupingEngine::Calculate::HcbCode#outgoing_fee_reimbursement?.
  #    This is a best-effort match: it can only key off week + amount, so a
  #    coincidental duplicate amount in the same window could match the wrong
  #    transaction.
  def settled_fee_reimbursement_transaction
    return @settled_fee_reimbursement_transaction if defined?(@settled_fee_reimbursement_transaction)

    @settled_fee_reimbursement_transaction = settled_transaction_by_weekly_short_code || settled_transaction_by_week_and_amount
  end

  private

  def outgoing_fee_reimbursement_hcb_code
    [
      ::TransactionGroupingEngine::Calculate::HcbCode::HCB_CODE,
      ::TransactionGroupingEngine::Calculate::HcbCode::OUTGOING_FEE_REIMBURSEMENT_CODE,
      processed_at.strftime("%G_%V"),
    ].join(::TransactionGroupingEngine::Calculate::HcbCode::SEPARATOR)
  end

  def settled_transaction_by_weekly_short_code
    return nil unless processed_at

    short_code = ::HcbCode.find_by(hcb_code: outgoing_fee_reimbursement_hcb_code)&.short_code
    return nil unless short_code.present?

    ::CanonicalTransaction.where("memo ilike ?", "%HCB-#{short_code}%").first
  end

  def settled_transaction_by_week_and_amount
    return nil unless processed_at && amount.present?

    ::CanonicalTransaction
      .where("hcb_code ilike ?", "HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::OUTGOING_FEE_REIMBURSEMENT_CODE}-%")
      .where(date: (processed_at.to_date - 1.day)..(processed_at.to_date + 10.days))
      .where(amount_cents: -amount)
      .first
  end

end
