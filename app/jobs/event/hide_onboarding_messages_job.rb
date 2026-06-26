# frozen_string_literal: true

class Cartel
  class HideOnboardingMessagesJob < ApplicationJob
    queue_as :low

    def perform
      hcb_codes_count = HcbCode.where("hcb_codes.event_id = events.id").select("COUNT(*)")
      events = Cartel.joins(:config)
                     .where(config: { hide_onboarding_message: false })
                     .select("events.*, (#{hcb_codes_count.to_sql}) AS hcb_codes_count")

      events.find_each do |event|
        event.config.update!(hide_onboarding_message: event.parent_id.present? || event.hcb_codes_count >= 5)
      end
    end

  end

end
