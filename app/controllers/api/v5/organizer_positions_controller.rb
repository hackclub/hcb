# frozen_string_literal: true

module Api
  module V5
    class OrganizerPositionsController < ApplicationController
      def index
        @organizer_positions = policy_scope(OrganizerPosition).includes(user: :organizer_positions).order(created_at: :desc)

        if params[:organization_id].present?
          @organizer_positions = @organizer_positions.where(event: Event.where_public_id(params[:organization_id]).or(Event.where(slug: params[:organization_id])))
        end

        @organizer_positions = paginate_cursor(@organizer_positions.to_a, &:public_id)
      end


      def removal_request
        organizer_position = authorize OrganizerPosition.find_by_public_id!(params[:id]), :can_request_removal?

        organizer_position.organizer_position_deletion_requests.create!(
          submitted_by: current_user,
          reason: params.require(:reason)
        )

        render json: { message: "Removal request submitted" }, status: :created
      end
    end
  end
end
