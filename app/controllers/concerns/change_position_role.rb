# frozen_string_literal: true

# Handles `change_position_role` route for
# both OrganizerPositionInvitesController and OrganizerPositionsController

module ChangePositionRole
  extend ActiveSupport::Concern

  included do
    def change_position_role
      position = (controller_name == "organizer_position_invites" ? OrganizerPositionInvite : OrganizerPosition).find(params[:id])
      authorize position

      was = position.role
      to = params[:to]

      if was != to
        position.update!(role: to)

        flash[:success] = "Changed #{position.user.name}'s role from #{was} to #{to}."
        if position.is_a?(OrganizerPosition)
          OrganizerPositionMailer.with(organizer_position: position, previous_role: was, changer: current_user).role_change.deliver_later
        end
      end

    rescue => e
      Rails.error.report(e)
      flash[:error] = position&.errors&.full_messages&.to_sentence.presence || "Failed to change the role."
    ensure
      redirect_back(fallback_location: event_team_path(position.event))
    end

  end

end
