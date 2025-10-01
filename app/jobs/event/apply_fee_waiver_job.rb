# frozen_string_literal: true

class Event
  class ApplyFeeWaiverJob < ApplicationJob
    queue_as :low

    DATE_LOCK = Date.new(2025, 11, 1)

    def perform
      Event.find_each do |event|
        process_event(event)
      end
    end

    private

    def process_event(event)
      active_teen_count = event.users.active_teenager.count

      if active_teen_count >= 5 && event.fee_waiver_eligible && Date.current < DATE_LOCK
        plan_type =
          if active_teen_count >= 10
            Event::Plan::Standard::FeeWaived
          else
            Event::Plan::Standard::ThreePointFive
          end

        ActiveRecord::Base.transaction do
          event.plan.update!(type: plan_type)
          event.update!(fee_waiver_applied: true)
        end

        return
      end

      return unless event.fee_waiver_applied

      ActiveRecord::Base.transaction do
        event.plan.update!(type: Event::Plan::Standard)
        event.update!(fee_waiver_applied: false)
      end
    end


  end

end
