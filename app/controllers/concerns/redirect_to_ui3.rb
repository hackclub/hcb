# frozen_string_literal: true

module RedirectToUI3
  extend ActiveSupport::Concern

  included do
    before_action :redirect_to_ui3_if_needed
  end

  private

  def redirect_to_ui3_if_needed
    return if current_user.nil?

    if Flipper.enabled?(:redirect_to_ui3_2025_11_03, current_user) && request.domain == "hcb.hackclub.com"
      redirect_to "https://ui3.hcb.hackclub.com#{request.fullpath}", allow_other_host: true
    end
  end
end
