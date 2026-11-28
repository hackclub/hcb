# frozen_string_literal: true

# The organization-level two-factor authentication requirements that apply to
# a user; see Event::TwoFactorAuthenticationRequirement.
class User
  module TwoFactorAuthenticationRequirement
    extend ActiveSupport::Concern

    # Organizations requiring two-factor authentication whose requirement
    # covers one of the user's positions (the organization itself, or one
    # above it).
    def events_requiring_two_factor_authentication
      return @events_requiring_two_factor_authentication if defined?(@events_requiring_two_factor_authentication)

      requiring_ids = Event.ids_requiring_two_factor_authentication
      @events_requiring_two_factor_authentication =
        if requiring_ids.empty?
          []
        else
          Event.where(id: requiring_ids).where(id: Event.self_and_ancestor_ids(organizer_positions.select(:event_id))).to_a
        end
    end

    # Organizations the user holds a position in but can't access until they
    # enable two-factor authentication.
    def events_locked_out_for_two_factor_authentication
      return Event.none if use_two_factor_authentication?

      overdue_ids = events_requiring_two_factor_authentication.select { |event| event.two_factor_authentication_deadline&.past? }.map(&:id)
      return Event.none if overdue_ids.empty?

      events.where(id: Event.self_and_descendant_ids(overdue_ids))
    end

  end

end
