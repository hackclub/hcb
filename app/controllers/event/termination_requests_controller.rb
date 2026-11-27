# frozen_string_literal: true

class Event
  class TerminationRequestsController < ApplicationController
    include SetEvent
    before_action :set_event

    def create
      @termination_request = @event.termination_requests.build(termination_request_params.merge(requested_by: current_user))
      authorize @termination_request

      if @termination_request.save
        flash[:success] = "Termination request submitted. Our team will be in touch shortly."
      else
        flash[:error] = @termination_request.errors.full_messages.to_sentence
      end

      redirect_to edit_event_path(@event, tab: "details")
    end

    def withdraw
      @termination_request = @event.termination_requests.find(params[:id])
      authorize @termination_request

      @termination_request.withdraw!

      flash[:success] = "Termination request withdrawn."
      redirect_to edit_event_path(@event, tab: "details")
    end

    private

    def termination_request_params
      params.require(:event_termination_request).permit(:reason)
    end

  end

end
