# frozen_string_literal: true

module StaticPageService
  class Index
    def initialize(current_user:)
      @current_user = current_user
    end

    def events
      @current_user.events.reorder("organizer_positions.sort_index ASC", "events.id ASC").includes(:stripe_cards, organizer_positions: :user)
    end

    def organizer_positions
      @current_user.organizer_positions.includes(:event).order(sort_index: :asc, event_id: :asc)
    end

    def invites
      @current_user.organizer_position_invites.pending
    end

    def invite_requests
      @current_user.organizer_position_invite_requests.pending
    end

    def applications
      @current_user.applications.active
    end

  end
end
