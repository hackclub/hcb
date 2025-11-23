# frozen_string_literal: true

require "rails_helper"

RSpec.describe FeaturesController do
  include SessionSupport
  render_views

  describe "#disable_feature" do
    it "requires sudo mode to disable sudo mode" do
      user = create(:user)
      Flipper.enable(:sudo_mode_2015_07_21, user)
      sign_in(user)

      travel(3.hours)

      post(:disable_feature, params: { feature: "sudo_mode_2015_07_21" })

      expect(response).to have_http_status(:unauthorized)
      expect(Flipper.enabled?(:sudo_mode_2015_07_21, user)).to eq(true)

      post(
        :disable_feature,
        params: {
          feature: "sudo_mode_2015_07_21",
          _sudo: {
            submit_method: "email",
            login_code: user.login_codes.last.code,
            login_id: user.logins.last.hashid,
          }
        }
      )

      expect(response).to have_http_status(:found)
      expect(Flipper.enabled?(:sudo_mode_2015_07_21, user)).to eq(false)
    end
  end
end
