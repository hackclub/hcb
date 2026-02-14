# frozen_string_literal: true

module SessionsHelper
  SESSION_DURATION_OPTIONS = {
    "15 minutes" => 15.minutes.to_i,
    "1 hour"     => 1.hour.to_i,
    "6 hours"    => 6.hours.to_i,
    "1 day"      => 1.day.to_i,
    "3 days"     => 3.days.to_i,
    "1 week"     => 1.week.to_i,
    "2 weeks"    => 2.weeks.to_i,
  }.freeze

  # For security reasons we severely restrict the duration of impersonated
  # sessions
  IMPERSONATED_SESSION_DURATION = SESSION_DURATION_OPTIONS.fetch("1 hour")

  class AccountLockedError < StandardError; end

  def impersonate_user(user)
    sign_out
    sign_in(user:, impersonate: true)
  end

  def unimpersonate_user
    curses = current_session
    sign_out
    sign_in(user: curses.impersonated_by)
  end

  # DEPRECATED - begin to start deprecating and ultimately replace with sign_in_and_set_cookie
  def sign_in(user:, fingerprint_info: {}, impersonate: false, webauthn_credential: nil)
    session_token = SecureRandom.urlsafe_base64
    session_duration =
      if impersonate
        IMPERSONATED_SESSION_DURATION
      else
        user.session_validity_preference
      end
    expiration_at = session_duration.seconds.from_now
    cookies.encrypted[:session_token] = { value: session_token, expires: User::Session::MAX_SESSION_DURATION.from_now, httponly: true }
    cookies.encrypted[:signed_user] = user.signed_id(expires_in: 2.months, purpose: :signin_avatar)
    user_session = user.user_sessions.build(
      session_token:,
      fingerprint: fingerprint_info[:fingerprint],
      device_info: fingerprint_info[:device_info],
      os_info: fingerprint_info[:os_info],
      timezone: fingerprint_info[:timezone],
      ip: fingerprint_info[:ip],
      webauthn_credential:,
      expiration_at:
    )

    if impersonate
      user_session.impersonated_by = current_user
    else
      raise(AccountLockedError, "Your HCB account has been locked.") if user.locked?
    end

    user_session.save!
    Current.session = user_session

    user_session
  end

  def signed_in?
    !current_user.nil?
  end

  def auditor_signed_in?
    signed_in? && current_user&.auditor?
  end

  def admin_signed_in?
    signed_in? && current_user&.admin?
  end

  def superadmin_signed_in?
    signed_in? &&
      current_user&.superadmin? &&
      !current_session&.impersonated?
  end

  def organizer_signed_in?(event = @event, as: :reader)
    run = ->(inner_event:, inner_as:) do
      next true if auditor_signed_in? && as == :reader
      next true if admin_signed_in? && as == :member
      next false unless signed_in? && inner_event.present?

      required_role_num = OrganizerPosition.roles[inner_as]
      raise ArgumentError, "invalid role #{inner_as}" unless required_role_num.present?

      valid_position = inner_event.ancestor_organizer_positions&.find do |op|
        next false unless op.user == current_user

        role_num = OrganizerPosition.roles[op.role]
        next false unless role_num.present?

        # Allows higher roles to succeed when checking for lower role
        # For example, `organizer_signed_in?(as: :member)` returns true if you're a manager
        role_num >= required_role_num
      end

      valid_position.present?
    end

    # Memoize results based on method arguments
    @organizer_signed_in ||= Hash.new do |h, key|
      h[key] = run.call(**key)
    end
    key = { inner_event: event, inner_as: as }
    @organizer_signed_in[key]
  end

  def current_user
    @current_user ||= current_session&.user
  end

  def current_session
    Current.session
  end

  def signed_in_user
    unless signed_in?
      if request.fullpath == "/"
        redirect_to auth_users_path(require_reload: true, signup: params[:signup])
      else
        redirect_to auth_users_path(return_to: request.original_url, require_reload: true, signup: params[:signup])
      end
    end
  end

  def signed_in_admin
    unless auditor_signed_in?
      redirect_to auth_users_path(require_reload: true), flash: { error: "You’ll need to sign in as an admin." }
    end
  end

  def sign_out
    current_session&.update(signed_out_at: Time.now, expiration_at: Time.now)

    cookies.delete(:session_token)
    Current.session = nil
  end

  def sign_out_of_all_sessions(user = current_user)
    # Destroy all the sessions except the current session
    user
      &.user_sessions
      &.where&.not(id: current_session.id)
      &.update_all(signed_out_at: Time.now, expiration_at: Time.now)
  end

  def sudo_mode?
    current_session&.sudo_mode?
  end

  # Intercepts the request and renders a reauthentication form if the user does
  # not have sudo mode.
  #
  # It can either be used as a `before_action` callback or as part of an action
  # implementation if you only want to require sudo mode in specific cases. In
  # the latter scenario, you _MUST_ check the return value and only proceed if
  # it is `true`.
  #
  # @return [Boolean] whether sudo mode was obtained and the controller action can proceed
  def enforce_sudo_mode
    return true if sudo_mode?

    SudoModeHandler.new(controller_instance: self).call
  end
end
