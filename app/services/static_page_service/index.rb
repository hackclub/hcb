# frozen_string_literal: true

module StaticPageService
  class Index
    # Associations rendered by `events/_event_card`, preloaded so each card
    # doesn't issue its own queries for the logo, background image, and
    # organizer avatars.
    EVENT_CARD_PRELOADS = [
      { logo_attachment: :blob },
      { background_image_attachment: :blob },
      { organizer_positions: { user: { profile_picture_attachment: :blob } } },
    ].freeze

    def initialize(current_user:)
      @current_user = current_user
    end

    def events
      @current_user.events.reorder("organizer_positions.sort_index ASC", "events.id ASC").preload(*EVENT_CARD_PRELOADS)
    end

    # { event_id => count } of active, main-ledger cards, matching the count
    # shown on each event card. One grouped query instead of one per card.
    def active_card_counts(events)
      StripeCard.active.on_main_ledger.where(event_id: events.map(&:id)).group(:event_id).count
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
