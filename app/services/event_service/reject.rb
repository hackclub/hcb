# frozen_string_literal: true

# TODO: DEPRECATED. DON'T USE. THIS LOGIC SHOULD BE LATER MOVED TO A PartneredSignupService

module EventService
  class Reject
    def initialize(event)
      @event = event
    end

    def run
      @event.mark_rejected!
      @event.aasm.current_state
    end

    private

  end
end
