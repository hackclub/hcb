# frozen_string_literal: true

# == Schema Information
#
# Table name: event_plans
#
#  id          :bigint           not null, primary key
#  aasm_state  :string
#  inactive_at :datetime
#  type        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  event_id    :bigint           not null
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
    FALLBACK_REVENUE_FEE = 0.07

    has_paper_trail

    belongs_to :event

    include AASM
    aasm timestamps: true do
      state :active, initial: true
      state :inactive

      event :mark_inactive do
        transitions from: :active, to: :inactive
        after do |new_type|
          event.reload
          event.create_plan!(type: new_type)
          unless event.plan.writeable?
            event.update(financially_frozen: true)
            event.stripe_cards.active.each do |card|
              card.freeze!(frozen_by: User.system_user)
            end
          end
          if event.plan.hidden?
            event.update(hidden_at: Time.now)
          end
        end
      end
    end

    def standard?
      type == Event::Plan::Standard.name
    end

    def default_values
      {}
    end

    def was_backfilled?
      created_at < Date.new(2024, 8, 24)
    end

    def revenue_fee_label
      ActionController::Base.helpers.number_to_percentage(revenue_fee * 100, precision: 1)
    end

    def self.available_features
      # this must contain every HCB feature that we want enable / disable with plans.
      %w[cards invoices donations account_number check_deposits transfers promotions google_workspace documentation reimbursements card_grants unrestricted_disbursements front_disbursements]
    end

    self.available_features.each do |feature|
      define_method("#{feature}_enabled?") do
        feature.in?(features)
      end
    end

    def self.available_plans
      Event::Plan.descendants
    end

    def self.available_plans_by_popularity
      available_plans.sort_by { |p| plan_popularities[p].presence || 0 }.reverse!
    end

    def self.plan_popularities
      Event::Plan.joins(:event).group(:type).select(:type, "count(*)").to_h { |p| [p.class, p.count] }
    end

    def self.that(method)
      self.available_plans.select { |plan| plan.new.try(method) }
    end

    validate do
      if Event::Plan.where(event_id:, aasm_state: :active).excluding(self).any?
        errors.add(:base, "An event can only have one active plan at a time.")
      end
    end

    validate do
      unless type.in?(Event::Plan.descendants.map(&:name))
        errors.add(:type, "is invalid")
      end
    end

  end

end
