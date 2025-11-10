# frozen_string_literal: true

module RedirectToUI3
  extend ActiveSupport::Concern

  included do
    before_action :redirect_to_ui3_if_needed
  end

  private

  def redirect_to_ui3_if_needed
    return if current_user.nil?
    # Only redirect GET and HEAD requests - POST/PUT/DELETE should reach the backend
    return unless request.get? || request.head?

    if Flipper.enabled?(:redirect_to_ui3_2025_11_03, current_user) && request.host == "hcb.hackclub.com"
      redirect_to "https://ui3.hcb.hackclub.com#{request.fullpath}", allow_other_host: true
    end
  end
end
