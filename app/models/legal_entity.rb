# frozen_string_literal: true

# == Schema Information
#
# Table name: legal_entities
#
#  id                :bigint           not null, primary key
#  archived_at       :datetime
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
#  index_legal_entities_on_tin_hash           (tin_hash)
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

  scope :managed, -> { where.not(managing_event_id: nil) }
  scope :unmanaged, -> { where(managing_event_id: nil) }
  scope :not_archived, -> { where(archived_at: nil) }

  validate :managing_event_cannot_change, on: :update
  validate :tin_hash_cannot_change, on: :update

  delegate :address_city, :address_country, :address_line1, :address_postal_code, :address_state, to: :latest_tax_form, allow_nil: true

  def tax_identification_number = Tax::IdentificationNumber.new(tin_hash:, legal_entity: self)

  def managed?
    managing_event_id.present?
  end

  # Re-check onboarding for any of this entity's contractor positions that are
  # mid-onboarding. Called when a step that lives on the legal entity (tax form,
  # payout method) completes.
  def refresh_contractor_onboarding!
    Payroll::Position.joins(:payee)
                     .where(payees: { legal_entity_id: id }, aasm_state: :onboarding)
                     .find_each(&:refresh_onboarding_state!)
  end

  # Deliberately the latest *completed* form, not latest_tax_form. A pending form
  # has a NULL completed_at, which Postgres sorts first on a DESC order, so
  # latest_tax_form becomes the new form the moment a payee starts one. Keying
  # payability off that would strand every pending payment of anyone who took us up
  # on "start a new tax form". A newly submitted TIN only blocks payouts once it
  # completes and turns out to disagree, which is what mismatched_tax_form catches.
  def payable?
    form = latest_completed_tax_form

    form.present? && mismatched_tax_form.nil? &&
      (form.taxbandits_tin_match_success? || !tax_identification_number.predicted_to_be_over_threshold?) &&
      !tin_banned? && !archived?
  end

  def latest_completed_tax_form
    @latest_completed_tax_form ||= tax_forms.completed.order(completed_at: :desc, created_at: :desc).first
  end

  # Whether tax info has ever been completed. Distinct from latest_tax_form, which
  # a freshly started (still pending) form outranks, so it must drive the UI's
  # "you're set up" state or starting a new form would look like losing the old one.
  def completed_tax_form?
    latest_completed_tax_form.present?
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

  # A completed form whose TIN is not the TIN this entity is already identified by.
  # Only forms that actually carry a fingerprint can mismatch: a pending form, a
  # failed one, and every form that predates TIN import all have a nil tin_hash,
  # and treating those as a mismatch would make the entity unpayable for no reason.
  def mismatched_tax_form
    return nil if tin_hash.nil?

    @mismatched_tax_form ||= tax_forms.not_discarded
                                      .completed
                                      .where.not(tin_hash: [nil, tin_hash])
                                      .order(completed_at: :desc, created_at: :desc)
                                      .first
  end

  def archive!
    update!(archived_at: Time.current)
  end

  def archived?
    archived_at.present?
  end

  def latest_usable_tax_form
    tax_forms.completed.where(tin_hash:).order(completed_at: :desc, created_at: :desc).first
  end

  delegate :masked_tin, to: :latest_usable_tax_form, allow_nil: true

  private

  def managing_event_cannot_change
    if managing_event_id_changed?
      errors.add(:managing_event_id, "cannot change once a legal entity is created")
    end
  end

  def tin_hash_cannot_change
    if tin_hash_changed? && tin_hash_was.present?
      errors.add(:tin_hash, "cannot change once set")
    end
  end

end
