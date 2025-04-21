# frozen_string_literal: true

class ErrorsController < ApplicationController
  skip_after_action :verify_authorized
  skip_before_action :signed_in_user, only: [:internal_server_error, :timeout]

  def not_found
    render status: :not_found
  end

  def bad_request
    render status: :bad_request, layout: "application"
  end

  def internal_server_error
    render status: :internal_server_error, layout: "application"
  end

  def timeout
    render status: :gateway_timeout, layout: "application"
  end

  def error
    @code = params[:code]
    Airbrake.notify("/#{@code} rendered.")
    render status: params[:code], layout: "application"
  end

end
