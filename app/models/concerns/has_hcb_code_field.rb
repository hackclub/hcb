# frozen_string_literal: true

module HasHcbCodeField
  extend ActiveSupport::Concern

  included do
    scope :missing_hcb_code, -> { where(hcb_code: nil) }
    scope :missing_or_unknown_hcb_code, -> { where("hcb_code is null or hcb_code ilike 'HCB-000%'") }
    scope :invoice_hcb_code, -> { where("hcb_code ilike 'HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::INVOICE_CODE}%'") }
    scope :donation_hcb_code, -> { where("hcb_code ilike 'HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::DONATION_CODE}%'") }
    scope :ach_transfer_hcb_code, -> { where("hcb_code ilike 'HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::ACH_TRANSFER_CODE}%'") }
    scope :check_hcb_code, -> { where("hcb_code ilike 'HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::CHECK_CODE}%'") }
    scope :outgoing_disbursement_hcb_code, -> { where("hcb_code ilike 'HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::OUTGOING_DISBURSEMENT_CODE}%'") }
    scope :incoming_disbursement_hcb_code, -> { where("hcb_code ilike 'HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::INCOMING_DISBURSEMENT_CODE}%'") }
    scope :stripe_card_hcb_code, -> { where("hcb_code ilike 'HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::STRIPE_CARD_CODE}%'") }
    scope :bank_fee_hcb_code, -> { where("hcb_code ilike 'HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::BANK_FEE_CODE}%'") }
  end
end
