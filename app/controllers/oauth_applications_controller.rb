# frozen_string_literal: true

class OauthApplicationsController < ApplicationController
  def revoke_tokens
    application = Doorkeeper::Application.find(params[:id])
    authorize application, policy_class: OauthApplicationPolicy

    now = Time.current
    # Not just the accessible tokens: an expired access token still carries a
    # refresh token that can mint a new one until its row is revoked.
    revoked_count = ApiToken.not_revoked.where(application:).update_all(revoked_at: now)
    Doorkeeper::AccessGrant.where(application:, revoked_at: nil).update_all(revoked_at: now)
    Doorkeeper::DeviceAuthorizationGrant::DeviceGrant.where(application:).delete_all

    redirect_to oauth_application_path(application), notice: "Revoked #{helpers.pluralize(revoked_count, "token")}."
  end

end
