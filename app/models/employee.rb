# frozen_string_literal: true

# == Schema Information
#
# Table name: employees
#
#  id          :bigint           not null, primary key
#  aasm_state  :string
#  deleted_at  :datetime
#  entity_type :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  entity_id   :bigint           not null
#  event_id    :bigint           not null
#  gusto_id    :string
#
# Indexes
#
#  index_employees_on_event_id  (event_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#
class Employee < ApplicationRecord
  include AASM
  include Hashid::Rails

  has_paper_trail
  acts_as_paranoid

  include PublicActivity::Model
  tracked owner: proc{ |controller, record| controller&.current_user }, event_id: proc { |controller, record| record.event.id }, only: [:create]

  validates_presence_of :gusto_id, if: -> { onboarded? }

  aasm do
    state :onboarding, initial: true
    state :onboarded
    state :terminated

    event :mark_onboarded do
      transitions from: :onboarding, to: :onboarded
    end

    event :mark_terminated do
      transitions from: [:onboarded, :onboarding], to: :terminated
    end
  end

  belongs_to :event
  belongs_to :entity, polymorphic: true
  has_many :payments

  after_create_commit do
    EmployeeMailer.with(employee: self).invitation.deliver_later
  end

  def user
    entity if entity.is_a?(User)
  end

  validate do
    if user.nil?
      errors.add(:entity, "must be a user")
    end
  end

end
