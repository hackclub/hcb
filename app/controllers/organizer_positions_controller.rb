# frozen_string_literal: true

class OrganizerPositionsController < ApplicationController
  include ChangePositionRole

  def destroy
    @organizer_position = OrganizerPosition.find(params[:id])
    authorize @organizer_position
    @organizer_position.destroy

    # also remove all organizer invites from the organizer that are still pending
    invites = @organizer_position.event.organizer_position_invites.pending.where(sender: @organizer_position.user)
    invites.each do |ivt|
      ivt.cancel
    end
    # also cancel all stripe cards from the organizer
    cards = @organizer_position.user.stripe_cards.where(event: @organizer_position.event)
    cards.each do |card|
      card.cancel! unless card.stripe_status == "canceled"
    end
    # ...and auto-close all deletion requests
    @organizer_position.organizer_position_deletion_requests.under_review.each { |opdt| opdt.close(current_user) }

    flash[:success] = "Removed #{@organizer_position.user.email} from the team and cancelled their cards."
    redirect_back(fallback_location: event_team_path(@organizer_position.event))
  end

  def set_index
    organizer_position = OrganizerPosition.find(params[:id])
    authorize organizer_position

    index = params[:index]

    # get all the organizer positions as an array
    organizer_positions = StaticPageService::Index.new(current_user:).organizer_positions.not_hidden.to_a

    return head status: :bad_request if index < 0 || index >= organizer_positions.size

    # switch the position *in the in-memory array*
    organizer_positions.delete organizer_position
    organizer_positions.insert index, organizer_position

    # persist the sort order
    ActiveRecord::Base.transaction do
      organizer_positions.each_with_index do |op, idx|
        op.update(sort_index: idx)
      end
    end

    render json: organizer_positions.pluck(:id)
  end

  def mark_visited
    organizer_position = OrganizerPosition.find(params[:id])
    authorize organizer_position

    organizer_position.update!(first_time: false)

    if params[:start_tour] == true
      start_tour organizer_position, :welcome

      ahoy.track "Tour started", organizer_position_id: organizer_position.id
    else
      ahoy.track "Tour skipped", organizer_position_id: organizer_position.id
    end

    redirect_to organizer_position.event
  end

  def toggle_signee_status
    organizer_position = OrganizerPosition.find(params[:id])
    authorize organizer_position
    unless organizer_position.update(is_signee: !organizer_position.is_signee?)
      flash[:error] = organizer_position.errors.full_messages.to_sentence.presence || "Failed to toggle signee status."
    end
    redirect_back(fallback_location: event_team_path(organizer_position.event))
  end

end
