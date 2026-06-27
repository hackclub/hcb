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
#  name                :string
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

  before_validation :normalize_address_country

  # We store countries as ISO 3166-1 alpha-2 codes (e.g. "US", "CA", "GB"),
  # matching the rest of our address fields and what we forward to Stripe.
  validates :address_country, inclusion: {
    in: ISO3166::Country.codes,
    message: "is not a valid country"
  }, allow_blank: true

  # address_state is intentionally left free-text for now. To validate it
  # strictly we'd check it against the country's ISO 3166-2 subdivisions
  # (`ISO3166::Country[address_country].subdivisions.keys`, as StripeCardholder
  # does), but that only works if the UI emits codes (a dependent dropdown),
  # since codes are non-obvious (Japan's prefectures are numeric, etc.).
  # Options when we're ready: (a) dependent subdivision dropdown + strict
  # validation, (b) keep it free-text like Stripe's API, or (c) populate it
  # from the W-9 / W-8BEN we'll already be collecting and skip asking twice.

  def complete?
    # Bypass until tax form is implemented
    # REQUIRED_COLUMNS.all? { |col| self[col].present? }

    true
  end

  private

  def normalize_address_country
    self.address_country = address_country&.strip&.upcase.presence
  end

end
