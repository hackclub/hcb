# frozen_string_literal: true

class HcbCode < ApplicationRecord
  include Hashid::Rails

  include Commentable
  include Receiptable

  monetize :amount_cents

  def url
    return "/ach_transfers/#{ach_transfer.id}" if ach_transfer?
    return "/checks/#{check.id}" if check?

    return "/hcb/#{local_hcb_code.hashid}" if local_hcb_code

    "/transactions/#{ct.id}"
  end

  def date
    @date ||= canonical_transactions.first.date
  end

  def memo
    return invoice_memo if invoice?
    return donation_memo if donation?
    return ach_transfer_memo if ach_transfer?
    return check_memo if check?
    return ct.smart_memo if stripe_card?

    ct.smart_memo
  end

  def amount_cents
    @amount_cents ||= begin
      return canonical_transactions.sum(:amount_cents) if canonical_transactions.exists?

      canonical_pending_transactions.sum(:amount_cents)
    end
  end

  def canonical_pending_transactions
    @canonical_pending_transactions ||= CanonicalPendingTransaction.where(hcb_code: hcb_code)
  end

  def canonical_transactions
    @canonical_transactions ||= CanonicalTransaction.where(hcb_code: hcb_code).order("date desc, id desc")
  end

  def event
    @event ||= canonical_pending_transactions.try(:first).try(:event) || canonical_transactions.try(:first).try(:event)
  end

  def fee_payment?
    ct.fee_payment?
  end

  def raw_stripe_transaction
    ct.raw_stripe_transaction
  end

  def invoice?
    hcb_i1 == ::TransactionGroupingEngine::Calculate::HcbCode::INVOICE_CODE
  end

  def donation?
    hcb_i1 == ::TransactionGroupingEngine::Calculate::HcbCode::DONATION_CODE
  end

  def ach_transfer?
    hcb_i1 == ::TransactionGroupingEngine::Calculate::HcbCode::ACH_TRANSFER_CODE
  end

  def check?
    hcb_i1 == ::TransactionGroupingEngine::Calculate::HcbCode::CHECK_CODE
  end

  def disbursement?
    hcb_i1 == ::TransactionGroupingEngine::Calculate::HcbCode::DISBURSEMENT_CODE
  end

  def stripe_card?
    hcb_i1 == ::TransactionGroupingEngine::Calculate::HcbCode::STRIPE_CARD_CODE
  end

  def local_hcb_code
    @local_hcb_code ||= HcbCode.find_or_create_by(hcb_code: hcb_code)
  end
  
  def invoice
    Invoice.find_by(id: hcb_i2)
  end

  def invoice_memo
    smartish_custom_memo || "INVOICE TO #{invoice.smart_memo}"
  end

  def donation
    Donation.find_by(id: hcb_i2)
  end

  def donation_memo
    smartish_custom_memo || "DONATION FROM #{donation.smart_memo}"
  end

  def ach_transfer
    AchTransfer.find(hcb_i2)
  end

  def ach_transfer_memo
    smartish_custom_memo || "ACH TO #{ach_transfer.smart_memo}"
  end

  def check
    Check.find(hcb_i2)
  end

  def check_memo
    smartish_custom_memo || "CHECK TO #{check.smart_memo}"
  end

  def disbursement
    Disbursement.find(hcb_i2)
  end

  def unknown?
    hcb_i1 == ::TransactionGroupingEngine::Calculate::HcbCode::UNKNOWN_CODE
  end

  def hcb_i1
    split_code[1]
  end

  def hcb_i2
    split_code[2]
  end

  def smart_hcb_code
    hcb_code || ::TransactionGroupingEngine::Calculate::HcbCode.new(canonical_transaction_or_canonical_pending_transaction: canonical_transactions.first)
  end

  def split_code
    @split_code ||= smart_hcb_code.split(::TransactionGroupingEngine::Calculate::HcbCode::SEPARATOR)
  end

  def canonical_transaction_ids
    JSON.parse(raw_canonical_transaction_ids)
  end

  def ct
    canonical_transactions.first
  end

  def ct2
    canonical_transactions.last
  end

  def smartish_custom_memo
    return nil unless ct.custom_memo
    return ct.custom_memo unless ct.custom_memo.include?("FEE REFUND")

    ct2.custom_memo
  end
end
