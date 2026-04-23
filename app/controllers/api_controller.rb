# frozen_string_literal: true

class ApiController < ApplicationController
  before_action :check_token, except: [:the_current_user, :flags]
  skip_before_action :verify_authenticity_token # do not use CSRF token checking for API routes
  skip_after_action :verify_authorized # do not force pundit
  skip_before_action :signed_in_user

  rescue_from(ActiveRecord::RecordNotFound) { render json: { error: "Record not found" }, status: :not_found }

  def the_current_user
    return head :not_found unless signed_in?

    render json: {
      avatar: helpers.profile_picture_for(current_user),
      name: current_user.name,
    }
  end

  def flags
    render json: Flipper.features.collect { |f| f.name }
  end

  private

  def check_token
    authed = authenticate_with_http_token do |token|
      ActiveSupport::SecurityUtils.secure_compare(token, Credentials.fetch(:API_TOKEN))
    end

    render json: { error: "Unauthorized" }, status: :unauthorized unless authed
  end

end
