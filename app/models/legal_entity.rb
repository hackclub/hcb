# frozen_string_literal: true

# == Schema Information
#
# Table name: legal_entities
#
#  id                :bigint           not null, primary key
#  banned_reason     :string
#  entity_type       :string
#  name              :string
#  tin_hash          :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  managing_event_id :bigint
#
# Indexes
#
#  index_legal_entities_on_managing_event_id  (managing_event_id)
#
class LegalEntity < ApplicationRecord
  self.ignored_columns += ["address_city", "address_country", "address_line1", "address_line2", "address_postal_code", "address_state"]
  include Hashid::Rails

  include PublicIdentifiable
  set_public_id_prefix :len

  # Some legal entities will be managed by events,
  # if a payment was sent by manually inputting details
  belongs_to :managing_event, class_name: "Event", optional: true

  enum :entity_type, { person: "person", business: "business" }

  has_many :legal_entity_users
  has_many :users, through: :legal_entity_users

  has_many :tax_forms, class_name: "Tax::Form"
  has_one :latest_tax_form, -> { order(completed_at: :desc, created_at: :desc) }, inverse_of: :legal_entity, class_name: "Tax::Form"

  has_many :payees
  has_many :payments, through: :payees

  has_many :payout_methods, class_name: "LegalEntity::PayoutMethod"
  # At most one default per entity is enforced by a partial unique index.
  has_one :default_payout_method, -> { where(default: true) }, class_name: "LegalEntity::PayoutMethod", inverse_of: :legal_entity

  after_create :send_tax_form!, if: -> { business? }

  scope :managed, -> { where.not(managing_event_id: nil) }
  scope :unmanaged, -> { where(managing_event_id: nil) }

  validate :managing_event_cannot_change, on: :update

  delegate :address_city, :address_country, :address_line1, :address_postal_code, :address_state, to: :latest_tax_form, allow_nil: true

  def tax_identification_number = Tax::IdentificationNumber.new(tin_hash:)

  def managed?
    managing_event_id.present?
  end

  def payable?
    latest_tax_form&.completed? &&
      (latest_tax_form.taxbandits_tin_match_success? || !tax_identification_number.predicted_to_be_over_threshold?) &&
      !tin_banned?
  end

  def send_tax_form!
    form = tax_forms.create!(external_service: :taxbandits)
    form.send!
  end

  def tin_banned?
    tax_identification_number.banned?
  end

  def display_name
    person? ? "Personal" : (name.presence || "Business")
  end

  private

  def managing_event_cannot_change
    if managing_event_id_changed?
      errors.add(:managing_event_id, "cannot change once a legal entity is created")
    end
  end

end
