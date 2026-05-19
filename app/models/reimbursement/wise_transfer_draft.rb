# frozen_string_literal: true

# == Schema Information
#
# Table name: reimbursement_wise_transfer_drafts
#
#  id                               :bigint           not null, primary key
#  address_city                     :string
#  address_line1                    :string
#  address_line2                    :string
#  address_postal_code              :string
#  address_state                    :string
#  bank_name                        :string
#  created_at                       :datetime         not null
#  currency                         :string           not null
#  recipient_country                :integer
#  recipient_email                  :string           not null
#  recipient_information_ciphertext :text
#  recipient_name                   :string           not null
#  recipient_phone_number           :string
#  reimbursement_report_id          :bigint           not null
#  updated_at                       :datetime         not null
#  wise_recipient_id                :text
#
# Indexes
#
#  idx_r_wise_transfer_drafts_on_report_id  (reimbursement_report_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (reimbursement_report_id => reimbursement_reports.id)
#

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
