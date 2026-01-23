# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # set Current.session - this should come first as
  # a large portion of the code below this depends on this
  before_action do
    Current.session = begin
      # Find a valid session (not expired) using the session token
      session_token = cookies.encrypted[:session_token]
      session_token.present? ? User::Session.not_expired.find_by(session_token:) : nil
    end
  end

  include Pundit::Authorization
  include SessionsHelper
  include ToursHelper
  include PublicActivity::StoreController
  include SetGovernanceRequestContext
  include ThemeDetection

  protect_from_forgery

  before_action :attach_error_reference

  # Ensure users are signed in. Create one-off exceptions to this on routes
  # that you want to be unauthenticated with skip_before_action.
  before_action :signed_in_user

  # Track papertrail edits to specific users
  before_action :set_paper_trail_whodunnit

  # Redirect users to the onboarding page if they haven't completed it yet
  before_action :redirect_to_onboarding

  # update the current session's last_seen_at
  before_action { Current.session&.update_session_timestamps }

  before_action do
    # Disallow indexing and following
    response.set_header("X-Robots-Tag", "none")
  end

  before_action do
    # Disallow all external redirects
    # https://hackclub.slack.com/archives/C047Y01MHJQ/p1743530368138499
    params[:return_to] = url_from(params[:return_to]) if params[:return_to]
  end

  # Enable Rack::MiniProfiler for auditors
  before_action do
    if current_user&.auditor?
      Rack::MiniProfiler.authorize_request
    end
  end

  before_action do
    unless signed_in?
      @hide_seasonal_decorations = true
    end
  end

  # Force usage of Pundit on actions
  after_action :verify_authorized, unless: -> { controller_path.starts_with?("doorkeeper/") || controller_path.starts_with?("audits1984/") }

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  rescue_from ActionView::MissingTemplate, with: :not_found

  rescue_from Rack::Timeout::RequestTimeoutException do
    respond_to do |format|
      format.html { render "errors/timeout" }
      format.all { render plain: "This request timed out, sorry." }
    end
  end

  def hide_footer
    @hide_footer = true
  end

  # @msw: this handles a bug caused by CSRF changes between Rails 6 -> 6.1. If
  # users signed into a session when Rails 6 was running, and then try to load a
  # page once Rails 6.1 is running, they'll get caught. See:
  # https://github.com/rails/rails/pull/41797
  # https://dev.to/nuttapon/handle-csrf-issue-when-upgrade-rails-from-5-to-6-1edp
  rescue_from ArgumentError do |exception|
    if request.format.html? && exception.message == "invalid base64"
      request.reset_session # reset your old existing session.
      redirect_to auth_users_path(require_reload: true) # your login page.
    else
      raise(exception)
    end
  end

  # Fallback for bad redirects that do not have allow_other_host set to true
  # https://blog.saeloun.com/2022/02/08/rails-7-raise-unsafe-redirect-error.html#after
  rescue_from ActionController::Redirecting::UnsafeRedirectError do |exception|
    if Rails.env.development?
      raise
    else
      Rails.error.report(exception)
      redirect_to root_url
    end
  end

  def find_current_auditor
    current_user if auditor_signed_in?
  end

  private

  def redirect_to_onboarding
    if current_user&.onboarding?
      redirect_to my_settings_path
    end
  end

  def user_not_authorized
    flash[:error] = "You are not authorized to perform this action."
    if current_user || !request.get?
      redirect_back_or_to root_path
    else
      redirect_to auth_users_path(return_to: request.url, require_reload: true)
    end
  end

  def not_found
    raise ActionController::RoutingError.new("Not Found")
  end

  def set_streaming_headers
    headers["X-Accel-Buffering"] = "no"
    headers["Cache-Control"] ||= "no-cache"
    headers.delete("Content-Length")
  end

  def confetti!(emojis: nil)
    flash[:confetti] = true
    flash[:confetti_emojis] = emojis.join(",") if emojis
  end

  def attach_error_reference
    error_reference = ErrorReference.from_request_id(request.uuid)
    Appsignal.add_tags(error_reference:) if defined?(Appsignal) && Appsignal.active?
  end

end
