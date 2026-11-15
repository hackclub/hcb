# frozen_string_literal: true

require "rails_helper"

RSpec.describe Login::Attempt do
  describe "#clear_ip_metadata!" do
    it "clears the IP address and user agent" do
      attempt = create(:login_attempt)

      attempt.clear_ip_metadata!

      expect(attempt.reload).to have_attributes(ip_address: nil, user_agent: nil)
    end
  end
end
