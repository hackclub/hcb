# frozen_string_literal: true

class OrganizerPosition
  module Spending
    class ControlsController < ApplicationController
      before_action :set_organizer_position

      def index
        @provisional_control = OrganizerPosition::Spending::Control.new(organizer_position: @organizer_position)

        authorize @provisional_control

        @active_control = @organizer_position.active_spending_control
        @inactive_control_count = @organizer_position.spending_controls.where(active: false).count

        if @active_control
          @provisional_allowance = @active_control.allowances.build
        end
      end

      def create
        attributes = filtered_params

        @control = @organizer_position.spending_controls.new(attributes)

        authorize @control

        if @control.save
          flash[:success] = "Spending control successfully created!"
          redirect_to event_organizer_position_spending_controls_path(@organizer_position)
        else
          render :new, status: :unprocessable_entity
        end
      end

      def destroy
        authorize @organizer_position.active_spending_control

        if active_control = @organizer_position.active_spending_control
          active_control.deactivate

          flash[:success] = "Spending controls disabled for #{@organizer_position.user.name}!"
          redirect_to event_organizer_position_spending_controls_path(organizer_position_id: @organizer_position)
        else
          flash[:error] = "There is no active spending control to delete"
          redirect_to root_path
        end
      end

      private

      def set_organizer_position
        @organizer_position = OrganizerPosition.find(params[:organizer_position_id])
        @event = @organizer_position.event
      end

      def filtered_params
        params.permit(:organizer_position_id)
      end

    end
  end

end
