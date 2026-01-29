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
    @referral_link = Referral::Link.find_by(slug: params[:referral]).presence if params[:referral].present?

    @signup = params[:signup] == "true"
  end

  # when you submit your email
  def create
    user = User.create_with(creation_method: :login).find_or_create_by!(email: params[:email])

    if params[:referral_link_id].present?
      referral_link = Referral::Link.find_by(slug: params[:referral_link_id]).presence
      login = user.logins.create(referral_program: referral_link&.program, referral_link:)
    else
      login = user.logins.create
    end

    cookies.signed["browser_token_#{login.hashid}"] = { value: login.browser_token, expires: Login::EXPIRATION.from_now }

    has_webauthn_enabled = user&.webauthn_credentials&.any?
    login_preference = session[:login_preference]

    if login_preference == "totp"
      redirect_to totp_login_path(login, return_to: params[:return_to]), status: :temporary_redirect
    elsif !has_webauthn_enabled || login_preference == "email" || login_preference == "sms"
      redirect_to login_code_login_path(login, return_to: params[:return_to]), status: :temporary_redirect
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
    remember = params[:remember] == "1"

    case params[:login_preference]
    when "email"
      session[:login_preference] = "email" if remember
      redirect_to login_code_login_path(@login), status: :temporary_redirect
    when "sms"
      session[:login_preference] = "sms" if remember
      redirect_to login_code_login_path(@login), status: :temporary_redirect
    when "totp"
      session[:login_preference] = "totp" if remember
      redirect_to totp_login_path(@login), status: :temporary_redirect
    when "webauthn"
      # This should never happen, because WebAuthn auth is handled on the frontend
      redirect_to choose_login_preference_login_path(@login)
    end
  end

  # post to request login code
  def login_code
    initialize_sms_params

    resp = LoginCodeService::Request.new(email: @email, sms: @use_sms_auth, ip_address: request.remote_ip, user_agent: request.user_agent).run

    @use_sms_auth = resp[:method] == :sms

    if resp[:error].present?
      flash[:error] = resp[:error]
      return redirect_to auth_users_path
    end

    render status: :unprocessable_entity

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
    when "login_code"
      ok = service.process_login_code(
        code: params[:login_code],
        sms: ActiveRecord::Type::Boolean.new.cast(params[:sms])
      )

      unless ok
        initialize_sms_params
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
    @login.with_lock do
      if @login.complete? && @login.user_session.nil?
        @login.update(user_session: sign_in(user: @login.user, fingerprint_info:))
      end
    end

    if @login.complete? && @login.user_session.present?
      if @referral_link.present?
        redirect_to referral_link_path(@referral_link)
      elsif @user.full_name.blank? || @user.phone_number.blank?
        redirect_to edit_user_path(@user.slug, return_to: params[:return_to])
      elsif @login.authenticated_with_backup_code && @user.backup_codes.active.empty?
        redirect_to security_user_path(@user), flash: { warning: "You've just used your last backup code, and we recommend generating more." }
      else
        return_path = params[:return_to]
        if return_path.present?
          begin
            route = Rails.application.routes.recognize_path(return_path)
            return_path = root_path if route[:controller] == "logins"
          rescue ActionController::RoutingError
            return_path = root_path
          end
        end
        redirect_to(return_path || root_path)
      end
    else
      if @login.sms_available? || @login.email_available?
        redirect_to login_code_login_path(@login), status: :temporary_redirect
      elsif @login.totp_available?
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

  def set_login
    begin
      if params[:id]
        @login = Login.incomplete.active.initial.find_by_hashid!(params[:id])
        @referral_link = @login.referral_link
        @referral_program = @referral_link&.program
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
    return if session[:login_preference] == "email" && !@login.authenticated_with_email

    if @login.user&.use_sms_auth || (@login.user&.phone_number_verified && (@login.authenticated_with_email || session[:login_preference] == "sms"))
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
