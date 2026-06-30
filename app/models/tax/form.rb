# frozen_string_literal: true

# == Schema Information
#
# Table name: tax_forms
#
#  id                  :bigint           not null, primary key
#  aasm_state          :string           not null
#  address_city        :string
#  address_country     :string
#  address_line1       :string
#  address_line2       :string
#  address_postal_code :string
#  address_state       :string
#  completed_at        :datetime
#  deleted_at          :datetime
#  external_service    :string           not null
#  failed_at           :datetime
#  form_type           :string
#  sent_at             :datetime
#  taxbandits_status   :string
#  tin_invalid         :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  external_id         :string
#  legal_entity_id     :bigint           not null
#
# Indexes
#
#  index_tax_forms_on_legal_entity_id  (legal_entity_id)
#
module Tax
  class Form < ApplicationRecord
    include AASM
    acts_as_paranoid
    has_paper_trail

    belongs_to :legal_entity

    enum :form_type, { W8BEN: "W8BEN", W9: "W9", W8BENE: "W8BENE", W8ECI: "W8ECI", W8IMY: "W8IMY", W8EXP: "W8EXP" }
    enum :external_service, { manual: "manual", taxbandits: "taxbandits" }, prefix: :sent_with

    # https://developer.taxbandits.com/docs/whcertificate/status/
    enum :taxbandits_status, %w[
      url_generated
      order_created
      scheduled
      sent
      opened
      completed
      awaiting_tin_certificate
      completed_and_tin_match_inprogress
      invalid
      bounced
      order_not_created
    ].index_with(&:itself), prefix: :taxbandits

    aasm timestamps: true do
      state :pending, initial: true
      state :sent # Request sent to TaxBandits, not necessarily email sent
      state :completed
      state :tin_invalid # TIN matching failed
      state :failed # Failed to create document / send email
    end

  end
end
