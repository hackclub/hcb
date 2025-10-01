# frozen_string_literal: true

class Event
  class ApplyFeeWaiverJob < ApplicationJob
    queue_as :low

    DATE_LOCK = Date.new(2025, 11, 1) # 👈 Move this to a constant as it doesn't change

    def perform
      Event.find_each do |event|
        process_event(event) # 👈 Move this logic to a method so we can use return
      end
    end

    private

    def process_event(event)
      active_teen_count = event.users.active_teenager.count

      # 👇 Combine two of the branches as they share a lot of logic
      if active_teen_count >= 5 && event.fee_waiver_eligible && Date.current < DATE_LOCK
        plan_type = # 👈 This is the only thing that changes between the branches so let's make that obvious
          if active_teen_count >= 10
            Event::Plan::Standard::FeeWaived
          else
            Event::Plan::Standard::ThreePointFive
          end

        # 👇 These two operations need to happen together so let's wrap them in a transaction
        ActiveRecord::Base.transaction do
          event.plan.update!(type: plan_type)
          event.update!(fee_waiver_applied: true)
        end

        return # 👈 Make it clear there's nothing left to do
      end

      # 👇 Move this conditional into a guard
      return unless event.fee_waiver_applied

      # 👇 These two operations need to happen together so let's wrap them in a transaction
      ActiveRecord::Base.transaction do
        event.plan.update!(type: Event::Plan::Standard)
        event.update!(fee_waiver_applied: false)
      end
    end


  end

end
