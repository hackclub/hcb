# frozen_string_literal: true

class OrganizerPosition
  module Spending
    class Control
      class AllowancesController < ApplicationController
        before_action :set_active_control

        def new
          @provisional_allowance = @active_control.allowances.build

          authorize @provisional_allowance
        end

        def create
          attributes = filtered_params
          attributes[:authorized_by_id] = current_user.id

          attributes[:amount] = params[:organizer_position_spending_control_allowance][:amount].to_f
          attributes[:amount] *= -1 if params[:organizer_position_spending_control_allowance][:operation] == "subtract"

          attributes[:memo] = params[:organizer_position_spending_control_allowance][:memo]

          @allowance = @active_control.allowances.build(attributes)

          authorize @allowance

          if @allowance.save
            flash[:success] = "Spending allowance created."
          else
            flash[:error] = @allowance.errors.full_messages.to_sentence
          end

          redirect_to event_organizer_position_spending_controls_path(@allowance.organizer_position)
        end

        private

        def set_active_control
          @active_control = OrganizerPosition::Spending::Control.find(params[:control_id])
        end

        def filtered_params
          params.permit(:amount, :memo)
        end

      end

    end
  end

end
