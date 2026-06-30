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
#  deleted_at          :datetime
#  external_service    :string           not null
#  form_type           :string
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

  end
end
