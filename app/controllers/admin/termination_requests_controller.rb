# frozen_string_literal: true

module Admin
  class TerminationRequestsController < Admin::BaseController
    before_action :set_termination_request, only: [:show, :close, :reopen]

    def index
      @termination_requests = Event::TerminationRequest
                              .order(Arel.sql("withdrawn_at IS NULL AND closed_at IS NULL DESC")) # pending first
                              .order(created_at: :desc)
                              .includes(:event, :requested_by, :closed_by)
                              .page(params[:page])
                              .per(safe_per(25))
    end

    def show
    end

    def close
      @termination_request.close!(current_user)

      redirect_to admin_termination_request_path(@termination_request), flash: { success: "Termination request closed." }
    end

    def reopen
      @termination_request.reopen!

      redirect_to admin_termination_request_path(@termination_request), flash: { success: "Termination request reopened." }
    end

    private

    def set_termination_request
      @termination_request = Event::TerminationRequest.find(params[:id])
    end

  end
end
