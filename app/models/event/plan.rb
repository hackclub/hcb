# frozen_string_literal: true

# == Schema Information
#
# Table name: event_plans
#
#  id         :bigint           not null, primary key
#  aasm_state :string
#  plan_type  :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  event_id   :bigint           not null
#
# Indexes
#
#  index_event_plans_on_event_id  (event_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#
class Event
  class Plan < ApplicationRecord
    belongs_to :event

    include AASM

    aasm do
      state :active, initial: true
      state :inactive

      event :mark_inactive do
        transitions from: :active, to: :inactive
        after do |new_plan_type|
          event.create_plan!(plan_type: new_plan_type)
        end
      end
    end

    def standard?
      plan_type == Event::Plan::Standard.name
    end

    def was_backfilled?
      created_at < Date.new(2024, 8, 24)
    end

    def revenue_fee_label
      ActionController::Base.helpers.number_to_percentage(revenue_fee * 100, precision: 1)
    end

    def self.available_features
      # this must contain every HCB feature that we want enable / disable with plans.
      %w[cards invoices donations account_number check_deposits transfers promotions google_workspace documentation reimbursements]
    end

    self.available_features.each do |feature|
      define_method("#{feature}_enabled?") do
        feature.in?(features)
      end
    end

    def self.available_plans
      Event::Plan.descendants
    end

    validate do
      if Event::Plan.where(event_id:, aasm_state: :active).excluding(self).any?
        errors.add(:base, "An event can only have one active plan at a time.")
      end
    end

  end

end
