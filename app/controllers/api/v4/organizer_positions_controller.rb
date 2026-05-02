# frozen_string_literal: true

module Api
  module V4
    class OrganizerPositionsController < ApplicationController
      include SetEvent
      include ApplicationHelper

      before_action :set_api_event, only: [:index]
      before_action :set_organizer_position, only: [:removal_request]

      def index
        authorize @event, :show_in_v4?
        positions = @event.organizer_positions.includes(:user).order(created_at: :desc).to_a
        @total_count = positions.size
        limit = [params[:limit]&.to_i || 25, 100].min

        start_index = if params[:after]
                        idx = positions.index { |op| op.public_id == params[:after] }
                        return render json: { error: "invalid_operation", messages: ["After parameter '#{params[:after]}' not found"] }, status: :bad_request if idx.nil?

                        idx + 1
                      else
                        0
                      end

        @has_more = positions.size > start_index + limit
        @organizer_positions = positions.slice(start_index, limit)
      end

      def removal_request
        authorize @organizer_position, :can_request_removal?

        @deletion_request = @organizer_position.organizer_position_deletion_requests.build(
          submitted_by: current_user,
          reason: params.require(:reason)
        )

        @deletion_request.save!

        render json: { message: "Removal request submitted" }, status: :created
      end

      private

      def set_organizer_position
        @organizer_position = OrganizerPosition.find_by_public_id!(params[:id])
      end

    end
  end
end
