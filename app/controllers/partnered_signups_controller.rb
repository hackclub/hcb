# frozen_string_literal: true

class PartneredSignupsController < ApplicationController
  before_action :set_partnered_signup, only: [:edit, :update]
  before_action :set_partner, only: [:edit, :update]
  skip_after_action :verify_authorized, only: [:edit, :update]
  skip_before_action :signed_in_user, only: [:edit, :update]

  # POST /api/v1/partnered_signups/new ..... NOT!
  def start
    # Are you looking for start? Psych! It's not here!
    # This controller manages all the views for the partner signup process, but the v1_controller manages all the JSON API endpoints
  end

  # GET /api/v1/partnered_signups/continue/:public_id
  # GET /partnered_signups/:public_id
  def edit
    # TODO: Pass through to signing if the form has already been submitted, but
    # contract has yet to be signed

    # Pass through to `redirect_url` if the form has already been signed
    redirect_to @partnered_signup.redirect_url, allow_other_host: true if @partnered_signup.applicant_signed?
  end

  # PATCH /partnered_signups/:public_id
  def update
    @partnered_signup.update(partnered_signup_params)
    authorize @partnered_signup

    @partnered_signup.mark_submitted! unless @partnered_signup.submitted?

    redirect_to @partnered_signup.redirect_url, allow_other_host: true

    # Send webhook to let Partner know that the Connect from has been submitted
    ::PartneredSignupJob::DeliverWebhook.perform_later(@partnered_signup.id)
  rescue => e
    notify_airbrake(e)
    render :edit, status: :unprocessable_entity
  end

  private

  def set_partnered_signup
    @partnered_signup = PartneredSignup.find_by_public_id(params[:public_id])
  end

  def set_partner
    @partner = @partnered_signup.partner
  end

  # Only allow a trusted parameter "white list" through.
  def partnered_signup_params
    params.require(:partnered_signup).permit(
      :organization_name,
      :owner_name,
      :owner_phone,
      :owner_email,
      :owner_address_line1,
      :owner_address_line2,
      :owner_address_city,
      :owner_address_state,
      :owner_address_postal_code,
      :owner_address_country,
      :owner_birthdate,
    )
  end

end
