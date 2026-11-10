# frozen_string_literal: true

class OauthApplicationsController < Doorkeeper::ApplicationsController
  skip_after_action :verify_authorized # access is gated by Doorkeeper's admin_authenticator

  private

  def application_params
    owner_email = params.dig(:doorkeeper_application, :owner_email)
    return super if owner_email.nil?

    @owner ||= User.find_by(email: owner_email)
    super.merge(owner: @owner)
  end

end
