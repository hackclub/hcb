# frozen_string_literal: true

class LoginsController < ApplicationController
  skip_before_action :signed_in_user, except: [:reauthenticate]
  skip_after_action :verify_authorized
  before_action :set_login, except: [:new, :create, :reauthenticate]
  before_action :set_user, except: [:new, :create, :reauthenticate]
  before_action :set_return_to

  layout "login"

  after_action only: [:new] do
    # Allow indexing login page
    response.delete_header("X-Robots-Tag")
  end

  # view to log in
  def new
    @return_to = url_from(params[:return_to])
    render "users/logout" if current_user

    @prefill_email = params[:email] if params[:email].present?
    @referral_program = Referral::Program.find_by_hashid(params[:referral]) if params[:referral].present?
  end

  # when you submit your email
  def create
    @user = User.create_with(creation_method: :login).find_or_create_by!(email: params[:email])

    referral_program = Referral::Program.find_by_hashid(params[:referral_program_id]) if params[:referral_program_id].present?
    login = @user.logins.create(referral_program:)

    cookies.signed["browser_token_#{login.hashid}"] = { value: login.browser_token, expires: Login::EXPIRATION.from_now }

    has_webauthn_enabled = @user&.webauthn_credentials&.any?

    if login_preference == "totp" && login.totp_available?
      redirect_to totp_login_path(login, return_to: params[:return_to]), status: :temporary_redirect
    elsif login_preference == "email" || login_preference.nil?
      redirect_to email_login_path(login, return_to: params[:return_to]), status: :temporary_redirect
    elsif login_preference == "sms" && login.sms_available?
      redirect_to sms_login_path(login, return_to: params[:return_to]), status: :temporary_redirect
    else
      session[:auth_email] = login.user.email
      redirect_to choose_login_preference_login_path(login, return_to: params[:return_to])
    end
  rescue => e
    flash[:error] = e.message
    return redirect_to auth_users_path
  end

  # get page to choose preference
  def choose_login_preference
    return redirect_to auth_users_path if @email.nil?

    session.delete :login_preference
  end

  # post to set preference
  def set_login_preference
    case params[:login_preference]
    when "email"
      redirect_to email_login_path(@login), status: :temporary_redirect
    when "sms"
      redirect_to sms_login_path(@login), status: :temporary_redirect
    when "totp"
      redirect_to totp_login_path(@login), status: :temporary_redirect
    when "webauthn"
      # This should never happen, because WebAuthn auth is handled on the frontend
      redirect_to choose_login_preference_login_path(@login)
    end
  end

  # post to request email login code
  def email
    resp = LoginCodeService::Request.new(email: @email, ip_address: request.remote_ip, user_agent: request.user_agent).run

    @use_sms_auth = false

    if resp[:error].present?
      flash[:error] = resp[:error]
      return redirect_to auth_users_path
    end

    render "logins/login_code", status: :unprocessable_entity

  rescue ActionController::ParameterMissing
    flash[:error] = "Please enter an email address."
    redirect_to auth_users_path
  end

  # post to request sms login code
  def sms
    initialize_sms_params

    resp = LoginCodeService::Request.new(email: @email, sms: @use_sms_auth, ip_address: request.remote_ip, user_agent: request.user_agent).run

    @use_sms_auth = resp[:method] == :sms

    if resp[:error].present?
      flash[:error] = resp[:error]
      return redirect_to auth_users_path
    end

    render "logins/login_code", status: :unprocessable_entity
  rescue ActionController::ParameterMissing
    flash[:error] = "Please enter an email address."
    redirect_to auth_users_path
  end

  # get to see totp page
  def totp
    render status: :unprocessable_entity
  rescue ActionController::ParameterMissing
    flash[:error] = "Please enter an email address."
    redirect_to auth_users_path
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
        redirect_to(auth_users_path, flash: { error: service.errors.full_messages.to_sentence })
        return
      end
    when "sms"
      ok = service.process_login_code(
        code: params[:login_code],
        sms: true
      )

      unless ok
        initialize_sms_params
        flash.now[:error] = service.errors.full_messages.to_sentence
        render(:login_code, status: :unprocessable_entity)
        return
      end
    when "email"
      ok = service.process_login_code(
        code: params[:login_code],
        sms: false
      )

      unless ok
        flash.now[:error] = service.errors.full_messages.to_sentence
        render(:login_code, status: :unprocessable_entity)
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
    if @login.complete? && @login.user_session.nil?
      @login.update(user_session: sign_in(user: @login.user, fingerprint_info:))
      if @referral_program.present?
        redirect_to program_path(@referral_program)
      elsif @user.full_name.blank? || @user.phone_number.blank?
        redirect_to edit_user_path(@user.slug, return_to: params[:return_to])
      elsif @login.authenticated_with_backup_code && @user.backup_codes.active.empty?
        redirect_to security_user_path(@user), flash: { warning: "You've just used your last backup code, and we recommend generating more." }
      else
        redirect_to(params[:return_to] || root_path)
      end
    else
      if @login.sms_available? && login_preference == "sms"
        redirect_to sms_login_path(@login), status: :temporary_redirect
      elsif @login.email_available? && login_preference == "email"
        redirect_to email_login_path(@login), status: :temporary_redirect
      elsif @login.totp_available? && login_preference == "totp"
        redirect_to totp_login_path(@login), status: :temporary_redirect
      else
        redirect_to choose_login_preference_login_path(@login, return_to: @return_to), status: :temporary_redirect
      end
    end
  rescue SessionsHelper::AccountLockedError => e
    redirect_to(auth_users_path, flash: { error: e.message })
  end

  def reauthenticate
    return unless enforce_sudo_mode

    redirect_to(@return_to || root_path)
  end

  private

  def login_preference(user: @user)
    return user.preferred_login_methods.first unless @login.present?

    authentication_factors = @login.authentication_factors&.filter_map { |key, value| key if value } || []

    (user.preferred_login_methods - authentication_factors).first
  end

  def set_login
    begin
      if params[:id]
        @login = Login.incomplete.active.initial.find_by_hashid!(params[:id])
        @referral_program = @login.referral_program
        unless valid_browser_token?
          # error! browser token doesn't match the cookie.
          flash[:error] = "This doesn't seem to be the browser who began this login; please ensure cookies are enabled."
          redirect_to auth_users_path
        end
      elsif session[:auth_email]
        @login = User.find_by_email(session[:auth_email]).logins.create
        cookies.signed["browser_token_#{@login.hashid}"] = { value: @login.browser_token, expires: Login::EXPIRATION.from_now }
      else
        flash[:error] = "Please try again."
        redirect_to auth_users_path
      end
    rescue ActiveRecord::RecordNotFound
      flash[:error] = "Please start again."
      redirect_to auth_users_path, flash: { error: "Please start again." }
    end
  end

  def set_user
    @user = @login.user
    @email = @login.user.email
  end

  def set_return_to
    @return_to = params[:return_to]
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

  def initialize_sms_params
    return if @login.authenticated_with_sms

    if @login.user&.use_sms_auth || @login.user&.phone_number_verified
      @use_sms_auth = true
      @phone_last_four = @login.user.phone_number.last(4)
    end
  end

  def valid_browser_token?
    return true if Rails.env.test?
    return true unless @login.browser_token
    return false unless cookies.signed["browser_token_#{@login.hashid}"]

    ActiveSupport::SecurityUtils.secure_compare(@login.browser_token, cookies.signed["browser_token_#{@login.hashid}"])
  end

end
