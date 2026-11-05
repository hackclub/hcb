# frozen_string_literal: true

class OauthApplicationsController < Doorkeeper::ApplicationsController
  skip_after_action :verify_authorized

  private

  def application_params
    owner = User.find_by(email: params.dig(:doorkeeper_application, :owner_email))
    super.merge(owner:)
  end

end
