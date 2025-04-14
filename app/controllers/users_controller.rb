# frozen_string_literal: true

class UsersController < ApplicationController
  skip_before_action :signed_in_user, only: [:webauthn_options]
  skip_before_action :redirect_to_onboarding, only: [:edit, :update, :logout, :unimpersonate]
  skip_after_action :verify_authorized, only: [:revoke_oauth_application,
                                               :edit_address,
                                               :edit_payout,
                                               :impersonate,
                                               :delete_profile_picture,
                                               :webauthn_options,
                                               :logout,
                                               :unimpersonate,
                                               :receipt_report,
                                               :edit_featurepreviews,
                                               :edit_security,
                                               :edit_notifications,
                                               :edit_admin,
                                               :toggle_sms_auth,
                                               :complete_sms_auth_verification,
                                               :start_sms_auth_verification]
  before_action :set_shown_private_feature_previews, only: [:edit, :edit_featurepreviews, :edit_security, :edit_admin]

  wrap_parameters format: :url_encoded_form

  def impersonate
    authorize current_user

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

  def webauthn_options
    return head :not_found if !params[:email]

    session[:auth_email] = params[:email]

    return head :not_found if params[:require_webauthn_preference] == "true" && session[:login_preference] != "webauthn"

    user = User.find_by(email: params[:email])

    return head :not_found if !user || user.webauthn_credentials.empty?

    options = WebAuthn::Credential.options_for_get(
      allow: user.webauthn_credentials.pluck(:webauthn_id),
      user_verification: "discouraged"
    )

    session[:webauthn_challenge] = options.challenge

    render json: options
  end

  def logout
    sign_out
    redirect_to root_path
  end

  def logout_all
    user = User.friendly.find(params[:id])
    authorize user
    sign_out_of_all_sessions(user)
    redirect_back_or_to security_user_path(user), flash: { success: "Success" }
  end

  def logout_session
    begin
      session = UserSession.find(params[:id])
      authorize session.user

      session.update(signed_out_at: Time.now, expiration_at: Time.now)
      flash[:success] = "Logged out of session!"
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
    set_onboarding
    @mailbox_address = @user.active_mailbox_address
    show_impersonated_sessions = auditor_signed_in? || current_session.impersonated?
    @sessions = show_impersonated_sessions ? @user.user_sessions : @user.user_sessions.not_impersonated
    authorize @user
  end

  def edit_address
    @user = params[:id] ? User.friendly.find(params[:id]) : current_user
    @states = ISO3166::Country.new("US").subdivisions.values.map { |s| [s.translations["en"], s.code] }
    redirect_to edit_user_path(@user) unless @user.stripe_cardholder
    @onboarding = @user.full_name.blank?
    show_impersonated_sessions = auditor_signed_in? || current_session.impersonated?
    @sessions = show_impersonated_sessions ? @user.user_sessions : @user.user_sessions.not_impersonated
    authorize @user
  end

  def edit_payout
    @user = params[:id] ? User.friendly.find(params[:id]) : current_user
    authorize @user
  end

  def edit_featurepreviews
    @user = params[:id] ? User.friendly.find(params[:id]) : current_user
    set_onboarding
    show_impersonated_sessions = auditor_signed_in? || current_session.impersonated?
    @sessions = show_impersonated_sessions ? @user.user_sessions : @user.user_sessions.not_impersonated
    authorize @user
  end

  def edit_security
    @user = params[:id] ? User.friendly.find(params[:id]) : current_user
    set_onboarding
    show_impersonated_sessions = auditor_signed_in? || current_session.impersonated?
    @sessions = show_impersonated_sessions ? @user.user_sessions : @user.user_sessions.not_impersonated
    @sessions = @sessions.not_expired
    @oauth_authorizations = @user.api_tokens
                                 .where.not(application_id: nil)
                                 .select("application_id, MAX(api_tokens.created_at) AS created_at, MIN(api_tokens.created_at) AS first_authorized_at, COUNT(*) AS authorization_count")
                                 .accessible
                                 .group(:application_id)
                                 .includes(:application)
    @all_sessions = (@sessions + @oauth_authorizations).sort_by { |s| s.created_at }.reverse!

    @expired_sessions = @user
                        .user_sessions
                        .recently_expired_within(1.week.ago)
                        .not_impersonated
                        .order(created_at: :desc)

    authorize @user
  end

  def edit_notifications
    @user = params[:id] ? User.friendly.find(params[:id]) : current_user
    authorize @user
  end

  def generate_totp
    @user = params[:id] ? User.friendly.find(params[:id]) : current_user
    authorize @user
    @user.totp&.mark_expired!
    @user.unverified_totp&.destroy!
    @totp = @user.create_unverified_totp
  end

  def enable_totp
    @user = params[:id] ? User.friendly.find(params[:id]) : current_user
    authorize @user
    @totp = @user.unverified_totp
    if @totp.may_mark_verified? && @totp.verify(params[:code], drift_behind: 15, after: @user.totp&.last_used_at)
      @user.totp&.mark_expired!
      @totp.mark_verified!
      redirect_back_or_to security_user_path(@user), flash: { success: "Your time-based OTP has been successfully configured." }
    else
      @invalid = true
      render :generate_totp
    end
  end

  def disable_totp
    @user = params[:id] ? User.friendly.find(params[:id]) : current_user
    authorize @user
    @user.totp&.mark_expired!
    redirect_back_or_to security_user_path(@user)
  end

  def edit_admin
    @user = params[:id] ? User.friendly.find(params[:id]) : current_user
    set_onboarding
    show_impersonated_sessions = auditor_signed_in? || current_session.impersonated?
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

    if admin_signed_in?
      if @user.auditor? && params[:user][:running_balance_enabled].present?
        enable_running_balance = params[:user][:running_balance_enabled] == "1"
        if @user.running_balance_enabled? != enable_running_balance
          @user.update_attribute(:running_balance_enabled, enable_running_balance)
        end
      end

      if params[:user][:locked].present?
        locked = params[:user][:locked] == "1"
        if @user == current_user
          flash[:error] = "As much as you might desire to, you cannot lock yourself out."
          return redirect_to admin_user_path(@user)
        elsif @user.admin? && !current_user.superadmin?
          flash[:error] = "Only superadmins can lock or unlock admins."
          return redirect_to admin_user_path(@user)
        elsif locked && @user.superadmin?
          flash[:error] = "To lock this user, demote them to a regular admin first."
          return redirect_to admin_user_path(@user)
        elsif locked
          @user.lock!
        else
          @user.unlock!
        end
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
      set_onboarding
      show_impersonated_sessions = auditor_signed_in? || current_session.impersonated?
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

  def set_onboarding
    @onboarding = @user.onboarding?
    @hide_seasonal_decorations = true if @onboarding
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
      :charge_notifications,
      :use_sms_auth,
      :use_two_factor_authentication
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

    if params.require(:user)[:payout_method_type] == User::PayoutMethod::Wire.name
      attributes << {
        payout_method_wire: [
          :address_line1,
          :address_line2,
          :address_city,
          :address_state,
          :address_postal_code,
          :recipient_country,
          :bic_code,
          :account_number
        ] + Wire.recipient_information_accessors
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

    p = params.require(:user).permit(attributes)

    # The Wire payout method attributes are under the `payout_method_wire` param instead of `payout_method_attributes` to prevent conflict with existing keys for other payout methods such as AchTransfer.
    # Rails requires that DOM form inputs have unique names.
    p[:payout_method_attributes] = p.delete(:payout_method_wire) if p[:payout_method_wire]

    p
  end

end
