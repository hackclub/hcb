# frozen_string_literal: true

class WebauthnCredentialsController < ApplicationController
  skip_before_action :signed_in_user, only: [:auth_options]
  skip_after_action :verify_authorized, only: [:auth_options]

  def register_options
    user = User.friendly.find(params[:user_id])

    authorize user, :edit?

    if !user.webauthn_id
      user.update!(webauthn_id: WebAuthn.generate_user_id)
    end

    options = WebAuthn::Credential.options_for_create(
      user: { id: user.webauthn_id, name: user.email, display_name: user.name },
      authenticator_selection: { authenticator_attachment: params[:type], user_verification: "discouraged" }
    )

    session[:webauthn_challenge] = options.challenge

    render json: options
  end

  def create
    user = User.friendly.find(params[:user_id])

    authorize user, :edit?

    webauthn_credential = WebAuthn::Credential.from_create(JSON.parse(params[:credential]))

    begin
      webauthn_credential.verify(session[:webauthn_challenge])

      user.webauthn_credentials.create!(
        webauthn_id: webauthn_credential.id,
        public_key: webauthn_credential.public_key,
        sign_count: webauthn_credential.sign_count,
        name: params[:name].presence || "#{browser.name} on #{browser.platform.name}",
        authenticator_type: params[:type]
      )

      redirect_back fallback_location: edit_user_path(user), flash: { success: "Registered security key!" }
    rescue WebAuthn::Error => e
      Airbrake.notify(e)
      redirect_back fallback_location: edit_user_path(user), flash: { error: "Something went wrong registering a security key." }
    end
  end

  def destroy
    credential = WebauthnCredential.find(params[:id])

    authorize credential

    credential.destroy

    redirect_back fallback_location: edit_user_path(params[:user_id]), flash: { success: "Deleted security key." }
  end

end
