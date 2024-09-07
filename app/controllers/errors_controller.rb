# frozen_string_literal: true

class ErrorsController < ApplicationController
  skip_after_action :verify_authorized
  skip_before_action :signed_in_user, only: [:internal_server_error]

  def not_found
    render status: :not_found
  end

  def internal_server_error
    render status: :internal_server_error, layout: "application"
  end

  def error
    @code = params[:code]
    Airbrake.notify("/#{@code} rendered.")
    render status: params[:code], layout: "application"
  end

end
