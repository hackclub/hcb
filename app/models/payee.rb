# frozen_string_literal: true

# == Schema Information
#
# Table name: payees
#
#  id              :bigint           not null, primary key
#  display_name    :string           not null
#  email           :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  event_id        :bigint           not null
#  legal_entity_id :bigint
#
# Indexes
#
#  index_payees_on_event_id                      (event_id)
#  index_payees_on_legal_entity_id               (legal_entity_id)
#  index_payees_on_legal_entity_id_and_event_id  (legal_entity_id,event_id) UNIQUE
#
class Payee < ApplicationRecord
  include PgSearch::Model
  include Hashid::Rails

  belongs_to :event
  belongs_to :legal_entity, optional: true

  has_many :payments

  validates_uniqueness_of :legal_entity_id, scope: [:event_id], allow_nil: true

  validate :managed_legal_entity_constraints

  pg_search_scope :search, against: [:display_name, :email], using: { tsearch: { prefix: true, dictionary: "english" } }

  after_update do
    if legal_entity_id_previously_changed?(from: nil)
      payments.pending_legal_entity.each(&:on_legal_entity_assigned)
    end
  end

  def search_avatar
    User.find_by(email:)
  end

  def managed?
    legal_entity&.managing_event_id.present?
  end

  private

  def managed_legal_entity_constraints
    return unless managed?

    if event_id != legal_entity.managing_event_id
      errors.add(:event, "must be the event managing this legal entity")
    end

    if legal_entity.payees.where.not(id:).exists?
      errors.add(:legal_entity, "is managed and can only have one payee")
    end
  end

end
