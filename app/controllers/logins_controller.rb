# frozen_string_literal: true

class LoginsController < ApplicationController
  # Longer than any URL a browser will navigate to, and `return_to` is stored
  # in `Login#state`, which is capped at 10KB.
  MAX_RETURN_TO_BYTES = 2.kilobytes

  skip_before_action :signed_in_user, except: [:reauthenticate]
  skip_after_action :verify_authorized
  before_action :set_login, except: [:new, :create, :reauthenticate]
  before_action :set_user, except: [:new, :create, :reauthenticate]
  invisible_captcha only: [:create, :complete], honeypot: :remember_me

  layout ->{ @login&.for_application? ? "apply" : "login" }

  after_action only: [:new] do
    # Allow indexing login page
    response.delete_header("X-Robots-Tag")
  end

  # view to log in
  def new
    render "users/logout" if current_user

    referral_link_id = Referral::Link.find_by(slug: params[:referral])&.slug if params[:referral].present?
    @login = Login.new(state: { return_to: requested_return_to, purpose: params[:purpose] }, referral_link_id:)

    @prefill_email = params[:email].presence || current_user(allow_unverified: true)&.email.presence
    @signup = params[:signup] == "true"
  end

  # when you submit your email
  def create
    referral_link = Referral::Link.find_by(slug: login_params[:referral_link_id]) if login_params[:referral_link_id].present?
    @login = Login.new(**login_params, referral_link:)

    @user = User.create_with(creation_method: @login.for_application? ? :application_form : :login).find_or_create_by!(email: params[:email])

    # An anonymous visitor only has a session if they arrived via a referral
    # link (see Referral::LinksController#show). No session means no clicks to
    # attribute, so there is nothing to transfer.
    current_session&.referral_attributions&.each do |attribution|
      attribution.update!(user: @user)
    end

    @login.user = @user
    @login.save!

    cookies.signed["browser_token_#{@login.hashid}"] = { value: @login.browser_token, expires: Login::EXPIRATION.from_now }

    continue_login(preference: login_preference || :email)
  rescue ActiveRecord::RecordInvalid => e
    return restart_login(error: e.record.errors.full_messages.to_sentence)
  rescue => e
    # Exception messages here can carry database internals (a unique violation
    # quotes the conflicting email), so report them rather than showing them.
    Rails.error.report(e)
    return restart_login(error: "Something went wrong signing you in. Please try again or contact HCB for support.")
  end

  # get page to choose preference
  def choose_login_preference
    if @email.nil?
      Rails.error.unexpected("[Login] Login #{@login.id} has a user without an email address.")
      return restart_login(error: "Something went wrong. Please try again or contact HCB for support.")
    end

    if @login.available_factors.none?
      Rails.error.unexpected("[Login] Login ran out of available factors. This should never be possible.")
      return restart_login(error: "Something went wrong. Please try again or contact HCB for support.")
    end

    session.delete :login_preference
  end

  # post to set preference
  def set_login_preference
    continue_login(preference: params[:login_preference]&.to_sym)
  end

  # post to request email login code
  def email
    resp = LoginCodeService::Request.new(email: @email, ip_address: request.remote_ip, user_agent: request.user_agent).run

    return restart_login(error: resp[:error]) if resp[:error].present?

    render status: :unprocessable_content
  end

  # post to request sms login code
  def sms
    # The UI only offers SMS for verified numbers; `continue_login` never
    # routes here otherwise. A request for an unverified number is a script
    # POSTing directly, spending a Twilio message on a number nobody has
    # proven they hold.
    unless @login.sms_available?
      flash[:error] = "SMS login isn't available for this account."
      return redirect_to auth_users_path
    end

    resp = LoginCodeService::Request.new(email: @email, sms: true, ip_address: request.remote_ip, user_agent: request.user_agent).run

    return restart_login(error: resp[:error]) if resp[:error].present?

    render status: :unprocessable_content
  end

  # get to see totp page
  def totp
    render status: :unprocessable_content
  end

  def complete
    # Clear the flash - this prevents the error message showing up after an unsuccessful -> successful login
    flash.clear

    service = ProcessLoginService.new(login: @login)

    case params[:method]
    when "webauthn"
      ok = service.process_webauthn(
        raw_credential: params[:credential],
        challenge: session[:webauthn_challenge]
      )

      unless ok
        restart_login(error: service.errors.full_messages.to_sentence)
        return
      end
    when "sms"
      ok = service.process_login_code(
        code: params[:login_code],
        sms: true
      )

      unless ok
        flash.now[:error] = service.errors.full_messages.to_sentence
        render(:sms, status: :unprocessable_content)
        return
      end
    when "email"
      ok = service.process_login_code(
        code: params[:login_code],
        sms: false
      )

      unless ok
        flash.now[:error] = service.errors.full_messages.to_sentence
        render(:email, status: :unprocessable_content)
        return
      end
    when "totp"
      ok = service.process_totp(code: params[:code])

      unless ok
        redirect_to(totp_login_path(@login), flash: { error: "Invalid TOTP code, please try again." })
        return
      end
    when "backup_code"
      ok = service.process_backup_code(code: params[:backup_code])

      unless ok
        redirect_to(backup_code_login_path(@login), flash: { error: service.errors.full_messages.to_sentence })
        return
      end
    end


    # Only create a user session if authentication factors are met AND this login
    # has not created a user session before
    @login.with_lock do
      if @login.complete? && @login.user_session.nil?
        @login.user.update(verified: true) unless @login.user.verified?
        sign_out
        @login.update(user_session: create_session(user: @login.user, verified: true, fingerprint_info:))
      end
    end

    if @login.complete? && @login.user_session.present?
      if @login.for_first?
        raffle = @login.state["raffle"]
        affiliations_attributes = @login.state.dig("user_params", "affiliations_attributes")
        Raffle.find_or_create_by!(user: @login.user, program: raffle) if raffle.present?
        @login.user.update!(affiliations_attributes:) if affiliations_attributes.present?
        redirect_to first_index_path
      elsif @referral_link.present?
        redirect_to referral_link_path(@referral_link)
      elsif (@user.full_name.blank? || @user.phone_number.blank?) && !@login.for_application?
        redirect_to edit_user_path(@user.slug, return_to: safe_return_to(@login.return_to))
      elsif @login.authenticated_with_backup_code && @user.backup_codes.active.empty?
        redirect_to security_user_path(@user), flash: { warning: "You've just used your last backup code, and we recommend generating more." }
      else
        return_path = safe_return_to(@login.return_to)

        if @user.only_draft_application? && return_path.blank?
          redirect_to application_path(@user.applications.first)
        else
          redirect_to(return_path || root_path)
        end
      end
    else
      continue_login
    end
  rescue SessionsHelper::AccountLockedError => e
    restart_login(error: e.message)
  end

  def reauthenticate
    return unless enforce_sudo_mode

    redirect_to(url_from(params[:return_to]) || root_path)
  end

  private

  def continue_login(preference: login_preference)
    if @login.sms_available? && preference == :sms
      redirect_to sms_login_path(@login), status: :temporary_redirect
    elsif @login.email_available? && preference == :email
      redirect_to email_login_path(@login), status: :temporary_redirect
    elsif @login.totp_available? && preference == :totp
      redirect_to totp_login_path(@login), status: :temporary_redirect
    elsif @login.webauthn_available? && preference == :webauthn
      redirect_to security_key_login_path(@login), status: :temporary_redirect
    else
      redirect_to choose_login_preference_login_path(@login)
    end
  end

  def login_params
    params
      .require(:login)
      .permit(:return_to, :purpose, :referral_link_id)
      # `ApplicationController` filters `params[:return_to]`, but not the
      # nested `login[return_to]` this form posts, so filter it here.
      .merge(return_to: safe_return_to(params.dig(:login, :return_to)))
  end

  # Reduces a candidate `return_to` to somewhere we're willing to send a user:
  # this host, a route that exists, and not back into the login flow they just
  # came out of.
  #
  # @return [String, nil]
  def safe_return_to(value)
    return nil if value.to_s.bytesize > MAX_RETURN_TO_BYTES

    url = url_from(value)
    return nil if url.blank?

    begin
      return nil if Rails.application.routes.recognize_path(url)[:controller] == "logins"
    rescue ActionController::RoutingError
      return nil
    end

    url
  end

  # The page the visitor was trying to reach before we asked them to sign in.
  def requested_return_to
    safe_return_to(params[:return_to])
  end

  # Sends the visitor back to the start of the login flow without dropping the
  # page they were originally trying to reach.
  #
  # @param error [String] flash error to show on the login page
  # @param login [Login, nil] the login to recover `return_to` from
  def restart_login(error:, login: @login)
    return_to = safe_return_to(login&.return_to) || requested_return_to
    flash[:error] = error

    redirect_to auth_users_path(return_to:)
  end

  def login_preference
    return @user.preferred_login_methods.first unless @login.present?

    authentication_factors = @login.authentication_factors&.filter_map { |key, value| key.to_sym if value } || []

    (@user.preferred_login_methods - authentication_factors & @login.available_factors).first
  end

  def set_login
    if params[:id]
      @login = Login.incomplete.active.initial.find_by_hashid(params[:id])

      unless @login
        # The login expired or never existed. Recover `return_to` from it so
        # the user doesn't lose the page they were heading to, but only for the
        # browser that began it: hashids are enumerable (they're salted with an
        # empty string), so a login that can't prove which browser started it
        # doesn't get to hand its `return_to` to whoever asks.
        expired = Login.initial.incomplete.find_by_hashid(params[:id])
        expired = nil unless expired&.browser_token.present? && valid_browser_token?(expired)

        return restart_login(error: "Please start again.", login: expired)
      end

      @referral_link = @login.referral_link
      @referral_program = @referral_link&.program

      unless valid_browser_token?
        # error! browser token doesn't match the cookie. Don't hand this
        # browser the other browser's `return_to`.
        return restart_login(
          error: "This doesn't seem to be the browser who began this login; please ensure cookies are enabled.",
          login: nil
        )
      end
    elsif session[:auth_email] && (user = User.find_by_email(session[:auth_email]))
      # Reached when a login begins without a persisted `Login` record: the
      # passkey flow on the login page and the "Sign in another way" link both
      # reach the collection routes, so `return_to` arrives as a param.
      @login = user.logins.create!(state: { return_to: requested_return_to, purpose: params[:purpose] })
      cookies.signed["browser_token_#{@login.hashid}"] = { value: @login.browser_token, expires: Login::EXPIRATION.from_now }
    else
      if session[:auth_email].present?
        # `UsersController#webauthn_options` stores the email before checking
        # that it belongs to anyone, so a typo leaves this pointing at nobody.
        # Left in place it makes every retry fail the same way.
        session.delete(:auth_email)
      end

      restart_login(error: "Please try again.")
    end
  end

  def set_user
    @user = @login.user
    @email = @login.user.email
  end

  def fingerprint_info
    {
      fingerprint: params[:fingerprint],
      device_info: params[:device_info],
      os_info: params[:os_info],
      timezone: params[:timezone],
      ip: request.remote_ip
    }
  end

  def valid_browser_token?(login = @login)
    # Specs drive logins without a browser, so they can't produce the cookie.
    # Those covering this check turn the bypass off (see config/environments/test.rb).
    # Compared against `true` because an unset `config.x` key reads back as an
    # empty `OrderedOptions`, which is truthy.
    return true if Rails.configuration.x.skip_login_browser_token_check == true
    return true unless login.browser_token
    return false unless cookies.signed["browser_token_#{login.hashid}"]

    ActiveSupport::SecurityUtils.secure_compare(login.browser_token, cookies.signed["browser_token_#{login.hashid}"])
  end

end
