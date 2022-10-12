# frozen_string_literal: true

class OrganizerPositionsController < ApplicationController
  def destroy
    @organizer_position = OrganizerPosition.find(params[:id])
    authorize @organizer_position
    @organizer_position.destroy

    # also remove all organizer invites from the organizer that are still pending
    invites = @organizer_position.event.organizer_position_invites.pending.where(sender: @organizer_position.user)
    invites.each do |ivt|
      ivt.cancel
    end

    flash[:success] = "Removed #{@organizer_position.user.email} from the team."
    redirect_back(fallback_location: event_team_path(@organizer_position.event))
  end

  def set_index
    organizer_position = OrganizerPosition.find(params[:id])
    authorize organizer_position

    index = params[:index]

    # get all the organizer positions as an array
    organizer_positions = StaticPageService::Index.new(current_user: current_user).organizer_positions.not_hidden.to_a

    return render status: :bad_request if index < 0 || index >= organizer_positions.size

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

end
