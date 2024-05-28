module OrganizerPositions
  module Spending
    class ControlsController < ApplicationController
      before_action :set_organizer_position

      def index
        @provisional_control = OrganizerPosition::Spending::Control.new(organizer_position: @organizer_position)

        authorize @provisional_control

        @active_control = @organizer_position.active_spending_control
        @inactive_control_count = @organizer_position.spending_controls.where(active: false).count
      end

      def new
        attributes = filtered_params
        attributes[:active] = true

        @control = @organizer_position.spending_controls.new(attributes)

        authorize @control

        if @control.save
          flash[:success] = "Spending control successfully created!"
          redirect_to event_organizer_controls_path organizer_id: @organizer_position
        else
          render :new, status: :unprocessable_entity
        end
      end

      def destroy
        authorize @organizer_position.active_spending_control

        if active_control = @organizer_position.active_spending_control
          if active_control.organizer_position_spending_allowances.count == 0
            active_control.destroy
          else
            active_control.update(active: false, ended_at: Time.current)
          end

          flash[:success] = "Spending controls disabled for #{@organizer_position.user.name}!"
          redirect_to event_organizer_controls_path organizer_id: @organizer_position
        else
          flash[:error] = "There is no active spending control to destroy"
          redirect_to root_path
        end
      end

      private

      def set_organizer_position
        @event = Event.friendly.find(params[:event_id])
        begin
          @user = User.friendly.find(params[:organizer_id])
          @organizer_position = OrganizerPosition.find_by!(event: @event, user: @user)
        rescue ActiveRecord::RecordNotFound
          @organizer_position = OrganizerPosition.find_by!(event: @event, id: params[:organizer_id])
        end
      end

      def filtered_params
        params.permit(:organizer_position_id)
      end

    end
  end
end
