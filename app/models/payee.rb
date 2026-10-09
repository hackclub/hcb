# frozen_string_literal: true

# == Schema Information
#
# Table name: payees
#
#  id              :bigint           not null, primary key
#  archived_at     :datetime
#  display_name    :string           not null
#  email           :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  event_id        :bigint           not null
#  legal_entity_id :bigint
#
# Indexes
#
#  index_payees_on_archived_at                   (archived_at)
#  index_payees_on_event_id                      (event_id)
#  index_payees_on_legal_entity_id               (legal_entity_id)
#  index_payees_on_legal_entity_id_and_event_id  (legal_entity_id,event_id) UNIQUE
#
class Payee < ApplicationRecord
  include PgSearch::Model

  include Hashid::Rails

  include PublicIdentifiable
  set_public_id_prefix :pye

  has_paper_trail

  belongs_to :event
  belongs_to :legal_entity, optional: true

  has_many :payments
  has_many :payroll_positions, class_name: "Payroll::Position"

  validates_uniqueness_of :legal_entity_id, scope: [:event_id], allow_nil: true

  validate :managed_legal_entity_constraints
  validate :email_frozen, if: -> { email_frozen? }

  normalizes :email, with: ->(email) { email.strip.downcase }

  scope :not_archived, -> { where(archived_at: nil) }

  pg_search_scope :search, against: [:display_name, :email], using: { tsearch: { prefix: true, dictionary: "english" } }

  after_update do
    if legal_entity_id_previously_changed?(from: nil)
      legal_entity.refresh_pending_contractors_payments!
    end
  end

  # Set when the email change reissued a contract the organizer must sign
  attr_reader :organizer_resign_position

  after_update_commit do
    @organizer_resign_position = nil
    if email_previously_changed?
      payments.where(aasm_state: :pending_legal_entity).find_each(&:send_initial_email)

      payroll_positions.where(aasm_state: [:under_review, :onboarding]).find_each do |position|
        reissue_contract_for_new_email(position)
      end
    end
  end

  def search_avatar
    User.find_by(email:)
  end

  def total_paid_cents
    # Use the in-memory association when it's already loaded (e.g. the
    # contractors index eager-loads payments) to avoid an N+1 of sum queries.
    if payments.loaded?
      payments.sum { |payment| payment.aasm_state == "successful" ? payment.amount_cents : 0 }
    else
      payments.where(aasm_state: "successful").sum(:amount_cents)
    end
  end

  def managed?
    legal_entity&.managing_event_id.present?
  end

  def archive!
    update!(archived_at: Time.current)
  end

  def archived?
    archived_at.present?
  end

  def email_frozen?
    legal_entity.present? && !legal_entity.managed?
  end

  private

  def reissue_contract_for_new_email(position)
    contract = position.contract
    return if contract.nil?
    return unless contract.party(:contractor)&.pending?

    contract.mark_voided!(reissuing: true)
    position.send_contract(
      reissue_of: contract,
      reissue_messages: { organizer: "The contractor's email address was updated, so the agreement was reissued with the new email." }
    )
    # The reissued contract needs HCB's signature again
    position.mark_under_review! if position.may_mark_under_review?
    @organizer_resign_position = position
  rescue Faraday::Error => e
    Rails.error.report(e, context: { payroll_position_id: position.id })
  end

  def managed_legal_entity_constraints
    return unless managed?

    if event_id != legal_entity.managing_event_id
      errors.add(:event, "must be the event managing this legal entity")
    end

    if legal_entity.payees.where.not(id:).exists?
      errors.add(:legal_entity, "is managed and can only have one payee")
    end
  end

  def email_frozen
    if persisted? && email_changed?
      errors.add(:email, "cannot change once a legal entity has been assigned")
    end
  end

end
