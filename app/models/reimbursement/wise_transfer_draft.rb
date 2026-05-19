# frozen_string_literal: true

module Reimbursement
  class WiseTransferDraft < ApplicationRecord
    include HasWiseRecipient

    has_encrypted :recipient_information, type: :json
    store :recipient_information, accessors: (recipient_information_accessors + ["account_holder"]).uniq

    belongs_to :report, class_name: "Reimbursement::Report", foreign_key: "reimbursement_report_id", inverse_of: :wise_transfer_draft

    validates :currency, presence: true
    validates :recipient_name, presence: true
    validates :recipient_email, presence: true
  end
end
