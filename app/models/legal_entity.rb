# frozen_string_literal: true

# == Schema Information
#
# Table name: legal_entities
#
#  id                  :bigint           not null, primary key
#  address_city        :string
#  address_country     :string
#  address_line1       :string
#  address_line2       :string
#  address_postal_code :string
#  address_state       :string
#  entity_type         :string
#  tin_hash            :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  managing_event_id   :bigint
#
# Indexes
#
#  index_legal_entities_on_managing_event_id  (managing_event_id)
#
class LegalEntity < ApplicationRecord
  REQUIRED_COLUMNS = %w[address_city address_country address_line1 address_postal_code address_state entity_type tin_hash].freeze
  # Some legal entities will be managed by events,
  # if a payment was sent by manually inputting details
  belongs_to :managing_event, class_name: "Event", optional: true

  enum :entity_type, { person: "person", business: "business" }

  has_many :legal_entity_users
  has_many :users, through: :legal_entity_users

  has_many :payout_methods, class_name: "LegalEntity::PayoutMethod"
  # At most one default per entity is enforced by a partial unique index.
  has_one :default_payout_method, -> { where(default: true) }, class_name: "LegalEntity::PayoutMethod", inverse_of: :legal_entity

  def complete?
    # Bypass until tax form is implemented
    # REQUIRED_COLUMNS.all? { |col| self[col].present? }

    true
  end

end
