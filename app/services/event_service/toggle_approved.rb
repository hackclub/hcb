# frozen_string_literal: true

# TODO: DEPRECATED. DON'T USE. THIS LOGIC SHOULD BE LATER MOVED TO A PartneredSignupService

module EventService
  class ToggleApproved
    def initialize(event)
      @event = event
    end

    def run
      if @event.approved?
        @event.mark_pending!
      else
        @event.mark_approved!
      end

      @event.aasm.current_state
    end

    private

  end
end
