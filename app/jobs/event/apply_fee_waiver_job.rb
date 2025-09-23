# frozen_string_literal: true

class Event
  class ApplyFeeWaiverJob < ApplicationJob
    queue_as :low

    def perform
      month_lock = 11
      Event.find_each do |event|
        active_teen_count = event.users.active_teenager.count
        if active_teen_count >= 5 && active_teen_count <= 9 && event.fee_waiver_eligible && Date.current.month < month_lock
          event.plan.update!(type: Event::Plan::Standard::ThreePointFive)
          event.update!(fee_waiver_applied: true)
        end

        if active_teen_count >= 10 && event.fee_waiver_eligible && Date.current.month < month_lock
          event.plan.update!(type: Event::Plan::Standard::FeeWaived)
          event.update!(fee_waiver_applied: true)
        end

        if (!event.fee_waiver_eligible || active_teen_count < 5 || Date.current.month >= month_lock) && event.fee_waiver_applied
          event.plan.update!(type: Event::Plan::Standard)
          event.update!(fee_waiver_applied: false)
        end
      end
    end

  end

end
