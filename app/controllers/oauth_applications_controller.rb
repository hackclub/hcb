# frozen_string_literal: true

class OauthApplicationsController < ApplicationController
  def revoke_tokens
    application = Doorkeeper::Application.find(params[:id])
    authorize application, policy_class: OauthApplicationPolicy

    # Grants go first: exchanging a code locks its grant row, so any token
    # minted from a code redeemed mid-revocation is committed before the token
    # update below runs, and gets revoked with the rest.
    application.access_grants.where(revoked_at: nil).update_all(revoked_at: Time.current)
    Doorkeeper::DeviceAuthorizationGrant::DeviceGrant.where(application:).delete_all

    # Not just the accessible tokens: an expired access token still carries a
    # refresh token that can mint a new one until its row is revoked. A refresh
    # already in progress can commit its new token after an update has started,
    # out of that update's sight, so keep sweeping until a pass finds nothing.
    revoked_count = 0
    loop do
      count = application.access_tokens.not_revoked.update_all(revoked_at: Time.current)
      break if count.zero?

      revoked_count += count
    end

    redirect_to oauth_application_path(application), notice: "Revoked #{helpers.pluralize(revoked_count, "token")}."
  end

end
