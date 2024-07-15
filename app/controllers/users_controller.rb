# frozen_string_literal: true

class UsersController < ApplicationController
  skip_before_action :signed_in_user, only: [:auth, :auth_submit, :choose_login_preference, :set_login_preference, :webauthn_options, :webauthn_auth, :login_code, :exchange_login_code, :totp, :totp_auth, :backup_code, :use_backup_code]
  skip_before_action :redirect_to_onboarding, only: [:edit, :update, :logout, :unimpersonate]
  skip_after_action :verify_authorized, only: [:choose_login_preference,
                                               :set_login_preference,
                                               :logout_all,
                                               :logout_session,
                                               :revoke_oauth_application,
                                               :auth,
                                               :edit_address,
                                               :edit_payout,
                                               :impersonate,
                                               :delete_profile_picture,
                                               :auth_submit,
                                               :webauthn_options,
                                               :webauthn_auth,
                                               :login_code,
                                               :exchange_login_code,
                                               :logout,
                                               :unimpersonate,
                                               :receipt_report,
                                               :edit_featurepreviews,
                                               :edit_security,
                                               :edit_admin,
                                               :toggle_sms_auth,
                                               :complete_sms_auth_verification,
                                               :start_sms_auth_verification,
                                               :totp,
                                               :totp_auth,
                                               :backup_code,
                                               :use_backup_code]
  before_action :set_shown_private_feature_previews, only: [:edit, :edit_featurepreviews, :edit_security, :edit_admin]
  before_action :migrate_return_to, only: [:auth, :auth_submit, :choose_login_preference, :login_code, :exchange_login_code, :webauthn_auth, :backup_code, :use_backup_code]

  wrap_parameters format: :url_encoded_form

  def impersonate
    authorize current_user

    return redirect_to root_path, flash: { error: "You cannot impersonate another user if you're already impersonating someone. " } if current_session&.impersonated?

    user = User.find(params[:id])

    impersonate_user(user)

    redirect_to params[:return_to] || root_path, flash: { info: "You're now impersonating #{user.name}." }
  end

  def unimpersonate
    return redirect_to root_path unless current_session&.impersonated?

    impersonated_user = current_user

    unimpersonate_user

    redirect_to params[:return_to] || root_path, flash: { info: "Welcome back, 007. You're no longer impersonating #{impersonated_user.name}" }
  end

  # view to log in
  def auth
    @prefill_email = params[:email] if params[:email].present?
    @return_to = params[:return_to]
  end

  def auth_submit
    @email = params[:email]
    user = User.find_by(email: @email)

    has_webauthn_enabled = user&.webauthn_credentials&.any?
    has_totp_enabled = user&.totp&.present?
    has_backup_codes_enabled = user&.backup_codes_list&.present?
    login_preference = session[:login_preference]

    if !has_webauthn_enabled && !has_totp_enabled && !has_backup_codes_enabled || login_preference == "email"
      redirect_to login_code_users_path, status: :temporary_redirect
    elsif login_preference == "totp" && has_totp_enabled
      redirect_to totp_users_path, status: :temporary_redirect
    else
      session[:auth_email] = @email
      redirect_to choose_login_preference_users_path(return_to: params[:return_to])
    end
  end

  def choose_login_preference
    @email = session[:auth_email]
    @user = User.find_by_email(@email)
    @webauthn_available = @user&.webauthn_credentials&.any?
    @totp_available = @user&.totp&.present?
    @return_to = params[:return_to]
    return redirect_to auth_users_path if @email.nil?

    session.delete :login_preference
  end

  def set_login_preference
    @email = params[:email]
    remember = params[:remember] == "1"

    case params[:login_preference]
    when "email"
      session[:login_preference] = "email" if remember
      redirect_to login_code_users_path, status: :temporary_redirect
    when "totp"
      session[:login_preference] = "totp" if remember
      redirect_to totp_users_path, status: :temporary_redirect
    when "backup_code"
      redirect_to backup_code_users_path, status: :temporary_redirect
    when "webauthn"
      # This should never happen, because WebAuthn auth is handled on the frontend
      redirect_to choose_login_preference_users_path
    end
  end

  # post to request login code
  def login_code
    @return_to = params[:return_to]
    @email = params.require(:email)
    @force_use_email = params[:force_use_email]

    initialize_sms_params

    resp = LoginCodeService::Request.new(email: @email, sms: @use_sms_auth, ip_address: request.ip, user_agent: request.user_agent).run

    @use_sms_auth = resp[:method] == :sms

    if resp[:error].present?
      flash[:error] = resp[:error]
      return redirect_to auth_users_path
    end

    if resp[:login_code]
      cookies.signed[:"browser_token_#{resp[:login_code].id}"] = { value: resp[:browser_token], expires: LoginCode::EXPIRATION.from_now }
    end

    @user_id = resp[:id]

    user = User.find_by(email: @email)
    @webauthn_available = user&.webauthn_credentials&.any?
    @totp_available = user&.totp&.present?

    render status: :unprocessable_entity

  rescue ActionController::ParameterMissing
    flash[:error] = "Please enter an email address."
    redirect_to auth_users_path
  end

  def webauthn_options
    return head :not_found if !params[:email]

    session[:auth_email] = params[:email]

    return head :not_found if params[:require_webauthn_preference] && session[:login_preference] != "webauthn"

    user = User.find_by(email: params[:email])

    return head :not_found if !user || user.webauthn_credentials.empty?

    options = WebAuthn::Credential.options_for_get(
      allow: user.webauthn_credentials.pluck(:webauthn_id),
      user_verification: "discouraged"
    )

    session[:webauthn_challenge] = options.challenge

    render json: options
  end

  def webauthn_auth
    user = User.find_by(email: params[:email])

    if !user
      return redirect_to auth_users_path
    end

    webauthn_credential = WebAuthn::Credential.from_get(JSON.parse(params[:credential]))

    stored_credential = user.webauthn_credentials.find_by!(webauthn_id: webauthn_credential.id)

    begin
      webauthn_credential.verify(
        session[:webauthn_challenge],
        public_key: stored_credential.public_key,
        sign_count: stored_credential.sign_count
      )

      stored_credential.update!(sign_count: webauthn_credential.sign_count)

      fingerprint_info = {
        fingerprint: params[:fingerprint],
        device_info: params[:device_info],
        os_info: params[:os_info],
        timezone: params[:timezone],
        ip: request.remote_ip
      }

      session[:login_preference] = "webauthn" if params[:remember] == "true"

      sign_in(user:, fingerprint_info:, webauthn_credential: stored_credential)

      redirect_to(params[:return_to] || root_path)

    rescue WebAuthn::SignCountVerificationError, WebAuthn::Error => e
      redirect_to auth_users_path, flash: { error: "Something went wrong." }
    rescue ActiveRecord::RecordInvalid => e
      redirect_to auth_users_path, flash: { error: e.record.errors&.full_messages&.join(". ") }
    end
  end

  def totp
    @return_to = params[:return_to]
    @email = params.require(:email)
    render status: :unprocessable_entity
  rescue ActionController::ParameterMissing
    flash[:error] = "Please enter an email address."
    redirect_to auth_users_path
  end

  def totp_auth
    user = User.find_by(email: params[:email])

    return redirect_to auth_users_path unless user.present?

    if user.totp&.verify(params[:code], drift_behind: 15, after: user.totp&.last_used_at)
      user.totp.update!(last_used_at: DateTime.now)
      fingerprint_info = {
        fingerprint: params[:fingerprint],
        device_info: params[:device_info],
        os_info: params[:os_info],
        timezone: params[:timezone],
        ip: request.remote_ip
      }
      sign_in(user:, fingerprint_info:)
      redirect_to(params[:return_to] || root_path)
    else
      redirect_to totp_users_path(email: params[:email]), flash: { error: "Invalid TOTP code, please try again." }
    end
  end

  def backup_code
    @email = params.require(:email)

    @user = User.find_by(email: @email)

    @user_id = @user.id

    return render :backup_code, status: :unprocessable_entity

  rescue ActionController::ParameterMissing
    flash[:error] = "Please enter an email address."
    redirect_to auth_users_path
  end

  # post to exchange auth token for access token
  def exchange_login_code
    fingerprint_info = {
      fingerprint: params[:fingerprint],
      device_info: params[:device_info],
      os_info: params[:os_info],
      timezone: params[:timezone],
      ip: request.remote_ip
    }

    user = UserService::ExchangeLoginCodeForUser.new(
      user_id: params[:user_id],
      login_code: params[:login_code],
      sms: params[:sms],
      cookies:
    ).run

    sign_in(user:, fingerprint_info:)

    # Clear the flash - this prevents the error message showing up after an unsuccessful -> successful login
    flash.clear

    if user.full_name.blank? || user.phone_number.blank?
      redirect_to edit_user_path(user.slug)
    else
      redirect_to(params[:return_to] || root_path)
    end
  rescue Errors::InvalidLoginCode, Errors::BrowserMismatch => e
    message = case e
              when Errors::InvalidLoginCode
                "Invalid login code!"
              when Errors::BrowserMismatch
                "Looks like this isn't the browser that requested that code!"
              end

    flash.now[:error] = message
    # Propagate the to the login_code page on invalid code
    @user_id = params[:user_id]
    @email = params[:email]
    @force_use_email = params[:force_use_email]
    initialize_sms_params
    return render :login_code, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    flash[:error] = e.record.errors&.messages&.values&.flatten&.join(". ")
    redirect_to auth_users_path
  end

  def use_backup_code
    backup_code = params[:backup_code]
    user = User.find_by(email: params[:email])
    return redirect_to auth_users_path unless user.present?

    fingerprint_info = {
      fingerprint: params[:fingerprint],
      device_info: params[:device_info],
      os_info: params[:os_info],
      timezone: params[:timezone],
      ip: request.remote_ip
    }
    unless user.backup_codes_list&.use_code!(code: backup_code, session: fingerprint_info)
      flash.now[:error] = "Invalid code!"
      @email = params[:email]
      return render :backup_code, status: :unprocessable_entity
    end
    sign_in(user:, fingerprint_info:)
    redirect_to(params[:return_to] || root_path)
  end

  def logout
    sign_out
    redirect_to root_path
  end

  def logout_all
    sign_out_of_all_sessions
    redirect_back_or_to security_user_path(current_user), flash: { success: "Success" }
  end

  def logout_session
    begin
      session = UserSession.find(params[:id])
      if session.user.id != current_user.id
        return redirect_back_or_to settings_security_path, flash: { error: "Error deleting the session" }
      end

      session.destroy!
      flash[:success] = "Deleted session!"
    rescue ActiveRecord::RecordNotFound => e
      flash[:error] = "Session is not found"
    end
    redirect_back_or_to settings_security_path
  end

  def revoke_oauth_application
    Doorkeeper::Application.revoke_tokens_and_grants_for(params[:id], current_user)
    redirect_back_or_to security_user_path(current_user)
  end

  def receipt_report
    ReceiptReportJob::Send.perform_later(current_user.id, force_send: true)
    flash[:success] = "Receipt report generating. Check #{current_user.email}"
    redirect_to settings_previews_path
  end

  def edit
    @user = params[:id] ? User.friendly.find(params[:id]) : current_user
    @onboarding = @user.onboarding?
    @mailbox_address = @user.active_mailbox_address
    show_impersonated_sessions = admin_signed_in? || current_session.impersonated?
    @sessions = show_impersonated_sessions ? @user.user_sessions : @user.user_sessions.not_impersonated
    authorize @user
  end

  def edit_address
    @user = params[:id] ? User.friendly.find(params[:id]) : current_user
    @states = [
      ISO3166::Country.new("US").subdivisions.values.map { |s| [s.translations["en"], s.code] },
      ISO3166::Country.new("CA").subdivisions.values.map { |s| [s.translations["en"], s.code] }
    ].flatten(1)
    redirect_to edit_user_path(@user) unless @user.stripe_cardholder
    @onboarding = @user.full_name.blank?
    show_impersonated_sessions = admin_signed_in? || current_session.impersonated?
    @sessions = show_impersonated_sessions ? @user.user_sessions : @user.user_sessions.not_impersonated
    authorize @user
  end

  def edit_payout
    @user = params[:id] ? User.friendly.find(params[:id]) : current_user
    authorize @user
  end

  def edit_featurepreviews
    @user = params[:id] ? User.friendly.find(params[:id]) : current_user
    @onboarding = @user.full_name.blank?
    show_impersonated_sessions = admin_signed_in? || current_session.impersonated?
    @sessions = show_impersonated_sessions ? @user.user_sessions : @user.user_sessions.not_impersonated
    authorize @user
  end

  def edit_security
    @user = params[:id] ? User.friendly.find(params[:id]) : current_user
    @onboarding = @user.full_name.blank?
    show_impersonated_sessions = admin_signed_in? || current_session.impersonated?
    @sessions = show_impersonated_sessions ? @user.user_sessions : @user.user_sessions.not_impersonated
    @oauth_authorizations = @user.api_tokens
                                 .where.not(application_id: nil)
                                 .select("application_id, MAX(api_tokens.created_at) AS created_at, MIN(api_tokens.created_at) AS first_authorized_at, COUNT(*) AS authorization_count")
                                 .accessible
                                 .group(:application_id)
                                 .includes(:application)
    @all_sessions = (@sessions + @oauth_authorizations).sort_by { |s| s.created_at }.reverse!

    @expired_sessions = @user
                        .user_sessions
                        .with_deleted
                        .not_impersonated
                        .where("deleted_at >= ? OR expiration_at >= ?", 1.week.ago, 1.week.ago)
                        .order(created_at: :desc)

    @backup_codes_last_generated = @user.backup_codes_list&.last_generated_at
    @backup_codes_remaining = @user.backup_codes_list&.codes&.count

    authorize @user
  end

  def enable_totp
    @user = params[:id] ? User.friendly.find(params[:id]) : current_user
    authorize @user
    @user.totp&.destroy!
    @user.create_totp!
  end

  def disable_totp
    @user = params[:id] ? User.friendly.find(params[:id]) : current_user
    authorize @user
    @user.totp&.destroy!
    redirect_back_or_to security_user_path(@user)
  end

  def generate_backup_codes
    @user = params[:id] ? User.friendly.find(params[:id]) : current_user
    @user_session = UserSession.find(params[:user_session_id])
    authorize @user
    unless @user.backup_codes_list
      @user.create_backup_codes_list!
    end
    @user.backup_codes_list&.user_regenerate_codes(session: @user_session)
  end

  def edit_admin
    @user = params[:id] ? User.friendly.find(params[:id]) : current_user
    @onboarding = @user.full_name.blank?
    show_impersonated_sessions = admin_signed_in? || current_session.impersonated?
    @sessions = show_impersonated_sessions ? @user.user_sessions : @user.user_sessions.not_impersonated

    # User Information
    @invoices = Invoice.where(creator: @user)
    @check_deposits = CheckDeposit.where(created_by: @user)
    @increase_checks = IncreaseCheck.where(user: @user)
    @lob_checks = Check.where(creator: @user)
    @ach_transfers = AchTransfer.where(creator: @user)
    @disbursements = Disbursement.where(requested_by: @user)

    authorize @user
  end

  def update
    @states = ISO3166::Country.new("US").subdivisions.values.map { |s| [s.translations["en"], s.code] }
    @user = User.friendly.find(params[:id])
    authorize @user

    if @user.admin? && params[:user][:running_balance_enabled].present?
      enable_running_balance = params[:user][:running_balance_enabled] == "1"
      if @user.running_balance_enabled? != enable_running_balance
        @user.update_attribute(:running_balance_enabled, enable_running_balance)
      end
    end

    if params[:user][:locked].present?
      locked = params[:user][:locked] == "1"
      if locked && @user == current_user
        flash[:error] = "As much as you might desire to, you cannot lock yourself out."
        return redirect_to admin_user_path(@user)
      elsif locked && @user.admin?
        flash[:error] = "Contact a engineer to lock out another admin."
        return redirect_to admin_user_path(@user)
      elsif locked
        @user.lock!
      else
        @user.unlock!
      end
    end

    email_change_requested = false

    if params[:user][:email].present? && params[:user][:email] != @user.email
      begin
        email_update = User::EmailUpdate.new(
          user: @user,
          original: @user.email,
          replacement: params[:user][:email],
          updated_by: current_user
        )
        email_update.save!
      rescue
        flash[:error] = email_update.errors.full_messages.to_sentence
        return redirect_back_or_to edit_user_path(@user)
      end
    end

    if @user.update(user_params)
      confetti! if !@user.seasonal_themes_enabled_before_last_save && @user.seasonal_themes_enabled? # confetti if the user enables seasonal themes

      if @user.full_name_before_last_save.blank?
        flash[:success] = "Profile created!"
        redirect_to root_path
      else
        if @user.payout_method&.saved_changes? && @user == current_user
          flash[:success] = "Your payout details have been updated. We'll use this information for all payouts going forward."
        elsif email_update&.requested?
          flash[:success] = "We've sent a verification link to your new email (#{params[:user][:email]}) and a authorization link to your old email (#{@user.email}), please click them both to confirm this change."
        else
          flash[:success] = @user == current_user ? "Updated your profile!" : "Updated #{@user.first_name}'s profile!"
        end

        ::StripeCardholderService::Update.new(current_user: @user).run

        redirect_back_or_to edit_user_path(@user)
      end
    else
      @onboarding = User.friendly.find(params[:id]).full_name.blank?
      show_impersonated_sessions = admin_signed_in? || current_session.impersonated?
      @sessions = show_impersonated_sessions ? @user.user_sessions : @user.user_sessions.not_impersonated
      if @user.stripe_cardholder&.errors&.any?
        flash.now[:error] = @user.stripe_cardholder.errors.first.full_message
        render :edit_address, status: :unprocessable_entity and return
      end
      if @user.payout_method&.errors&.any?
        flash.now[:error] = @user.payout_method.errors.first.full_message
        render :edit_payout, status: :unprocessable_entity and return
      end
      render :edit, status: :unprocessable_entity
    end
  end

  def delete_profile_picture
    @user = User.friendly.find(params[:user_id])
    authorize @user

    @user.profile_picture.purge_later

    flash[:success] = "Switched back to your Gravatar."
    redirect_to edit_user_path(@user.slug)
  end

  def start_sms_auth_verification
    authorize current_user
    svc = UserService::EnrollSmsAuth.new(current_user)
    svc.start_verification
    # flash[:info] = "Verifying phone number"
    # redirect_to edit_user_path(current_user)
    render json: { message: "started verification successfully" }, status: :ok
  end

  def complete_sms_auth_verification
    authorize current_user
    params.require(:code)
    svc = UserService::EnrollSmsAuth.new(current_user)
    svc.complete_verification(params[:code])
    svc.enroll_sms_auth if params[:enroll_sms_auth]
    # flash[:success] = "Completed verification"
    # redirect_to edit_user_path(current_user)
    render json: { message: "completed verification successfully" }, status: :ok
  rescue ::Errors::InvalidLoginCode
    # flash[:error] = "Invalid login code"
    # redirect_to edit_user_path(current_user)
    render json: { error: "invalid login code" }, status: :forbidden
  end

  def toggle_sms_auth
    authorize current_user
    svc = UserService::EnrollSmsAuth.new(current_user)
    if current_user.use_sms_auth
      svc.disable_sms_auth
    else
      svc.enroll_sms_auth
    end
    redirect_back_or_to security_user_path(current_user)
  end

  private

  def set_shown_private_feature_previews
    @shown_private_feature_previews = params[:classified_top_secret]&.split(",") || []
  end

  def user_params
    attributes = [
      :full_name,
      :preferred_name,
      :phone_number,
      :profile_picture,
      :pretend_is_not_admin,
      :sessions_reported,
      :session_duration_seconds,
      :receipt_report_option,
      :birthday,
      :seasonal_themes_enabled,
      :payout_method_type,
      :comment_notifications,
      :charge_notifications
    ]

    if @user.stripe_cardholder
      attributes << {
        stripe_cardholder_attributes: [
          :stripe_billing_address_line1,
          :stripe_billing_address_line2,
          :stripe_billing_address_city,
          :stripe_billing_address_state,
          :stripe_billing_address_postal_code,
          :stripe_billing_address_country
        ]
      }
    end

    if params.require(:user)[:payout_method_type] == User::PayoutMethod::Check.name
      attributes << {
        payout_method_attributes: [
          :address_line1,
          :address_line2,
          :address_city,
          :address_state,
          :address_postal_code,
          :address_country
        ]
      }
    end

    if params.require(:user)[:payout_method_type] == User::PayoutMethod::AchTransfer.name
      attributes << {
        payout_method_attributes: [
          :account_number,
          :routing_number
        ]
      }
    end

    if params.require(:user)[:payout_method_type] == User::PayoutMethod::PaypalTransfer.name
      attributes << {
        payout_method_attributes: [
          :recipient_email
        ]
      }
    end

    if superadmin_signed_in?
      attributes << :access_level
    end

    params.require(:user).permit(attributes)
  end

  def initialize_sms_params
    return if @force_use_email

    user = User.find_by(email: @email)
    if user&.use_sms_auth
      @use_sms_auth = true
      @phone_last_four = user.phone_number.last(4)
    end
  end

  # HCB used to run on bank.hackclub.com— this ensures that any old references to `bank.` URLs are translated into `hcb.`
  def migrate_return_to
    if params[:return_to].present?
      uri = URI(params[:return_to])

      if uri&.host == "bank.hackclub.com"
        uri.host = "hcb.hackclub.com"
        params[:return_to] = uri.to_s
      end
    end

  rescue URI::InvalidURIError
    params.delete(:return_to)
  end

end
