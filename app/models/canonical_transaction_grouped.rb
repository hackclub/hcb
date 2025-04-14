# frozen_string_literal: true

class CanonicalTransactionGrouped
  include ActiveModel::Model

  attr_accessor :hcb_code, :date, :amount_cents, :raw_canonical_transaction_ids, :raw_canonical_pending_transaction_ids, :event, :running_balance, :subledger
  attr_writer :canonical_transactions, :canonical_pending_transactions, :local_hcb_code

  delegate :likely_account_verification_related?,
           :fee_payment?,
           :fee_reimbursement?,
           :raw_stripe_transaction,
           :stripe_cardholder, to: :ct, allow_nil: true
  delegate :invoice?,
           :donation?,
           :ach_transfer?,
           :check?,
           :disbursement?,
           :stripe_card?,
           :stripe_refund?,
           :unknown?, to: :local_hcb_code

  def memo
    return invoice_memo if invoice?
    return donation_memo if donation?
    return ach_transfer_memo if ach_transfer?
    return check_memo if check?
    return ct&.smart_memo if stripe_card?

    pt&.smart_memo
    ct&.smart_memo
  end

  def amount
    @amount ||=
      begin
        # If this CanonicalTransactionGrouped is a CT, get it's pending
        # transactions and sum their their fronted amount. This allows the total
        # amount of an invoice/donation to show when only the payout has arrived.

        # Having no pt means it is a ct (the sql query below makes it mutually exclusive)
        if canonical_pending_transactions.none?
          # Getting pending transactions from hcb code since the
          # `canonical_pending_transactions` method in this class will be empty
          # if this CanonicalTransactionGrouped represents a CanonicalTransaction
          pts = local_hcb_code.canonical_pending_transactions.select { |pt| pt.fronted? && pt.event == event && pt.subledger == subledger }
          return Money.new(amount_cents + pts.sum(&:fronted_amount), "USD")
        end

        # Otherwise, this transaction is just a PT, and the `amount_cents`
        # should already reflect the full amount
        Money.new(amount_cents, "USD")
      end
  end

  def url
    if disbursement? && ct && disbursement?
      return "/transactions/#{ct.id}" # because disbursements go across 2 events
    end

    return "/hcb/#{local_hcb_code.hashid}" if local_hcb_code

    if ct
      return "/transactions/#{ct.id}"
    end

    "/canonical_pending_transactions/#{pt.id}"
  end

  def canonical_pending_transactions
    @canonical_pending_transactions ||= CanonicalPendingTransaction.where(id: canonical_pending_transaction_ids).order("date desc, id desc")
  end

  def canonical_transactions
    @canonical_transactions ||= CanonicalTransaction.where(id: canonical_transaction_ids).order("date desc, id desc")
  end

  def fee_reimbursed?
    ct&.fee_reimbursement&.completed?
  end

  def local_hcb_code
    @local_hcb_code ||= HcbCode.find_or_create_by(hcb_code:)
  end

  def canonical_pending_transaction_ids
    return [] if raw_canonical_pending_transaction_ids.nil?

    JSON.parse(raw_canonical_pending_transaction_ids)
  end

  def canonical_transaction_ids
    return [] if raw_canonical_transaction_ids.nil?

    JSON.parse(raw_canonical_transaction_ids)
  end

  private

  def invoice
    Invoice.find(hcb_i2)
  end

  def invoice_memo
    smartish_custom_memo || "Invoice to #{invoice.smart_memo}".stripe.upcase
  end

  def donation
    Donation.find(hcb_i2)
  end

  def donation_memo
    smartish_custom_memo || "Donation from #{donation.smart_memo}".strip.upcase
  end

  def ach_transfer
    AchTransfer.find(hcb_i2)
  end

  def ach_transfer_memo
    smartish_custom_memo || "ACH to #{ach_transfer.smart_memo}".strip.upcase
  end

  def check
    Check.find(hcb_i2)
  end

  def check_memo
    smartish_custom_memo || "Check to #{check.smart_memo}".strip.upcase
  end

  def disbursement
    Disbursement.find(hcb_i2)
  end

  def hcb_i1
    split_code[1]
  end

  def hcb_i2
    split_code[2]
  end

  def smart_hcb_code
    hcb_code ||
      ::TransactionGroupingEngine::Calculate::HcbCode.new(canonical_transaction_or_canonical_pending_transaction: ct) ||
      ::TransactionGroupingEngine::Calculate::HcbCode.new(canonical_transaction_or_canonical_pending_transaction: pt)
  end

  def split_code
    @split_code ||= smart_hcb_code.split(::TransactionGroupingEngine::Calculate::HcbCode::SEPARATOR)
  end

  def pt
    canonical_pending_transactions.first
  end

  def ct
    canonical_transactions.first
  end

  def ct2
    canonical_transactions.last
  end

  def smartish_custom_memo
    return nil unless ct&.custom_memo
    return ct&.custom_memo unless ct&.custom_memo&.include?("FEE REFUND")

    ct2.custom_memo
  end

end
