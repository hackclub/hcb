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
#  document_url        :string
#  external_service    :string           not null
#  external_status     :string
#  failed_at           :datetime
#  form_type           :string
#  invalid_at          :datetime
#  sent_at             :datetime
#  tin_hash            :string
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

    aasm timestamps: true do
      state :pending, initial: true
      state :sent # Request sent to TaxBandits, not necessarily email sent
      state :completed
      state :invalid # TIN matching failed
      state :failed # Failed to create document / send email
    end

  end
end
