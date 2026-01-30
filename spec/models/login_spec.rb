# frozen_string_literal: true

require "rails_helper"

RSpec.describe Login do
  describe "#complete?" do
    it "is true when 2fa is not enabled and one factor was used" do
      user = create(:user, use_two_factor_authentication: false)
      login = create(:login, user:)

      login.update!(authenticated_with_email: true)

      expect(login).to be_complete
    end

    it "is false when 2fa is enabled and one factor was used" do
      user = create(:user, use_two_factor_authentication: true, phone_number: "+18556254225", phone_number_verified: true, use_sms_auth: true)
      login = create(:login, user:)

      login.update!(authenticated_with_email: true)

      expect(login).not_to be_complete
    end

    it "is true when 2fa is enabled and two factors were used" do
      user = create(:user, use_two_factor_authentication: true, phone_number: "+18556254225", phone_number_verified: true, use_sms_auth: true)
      login = create(:login, user:)

      login.update!(authenticated_with_email: true)
      login.update!(authenticated_with_totp: true)

      expect(login).to be_complete
    end

    it "is true when the login is a reauthentication and one factor was used regardless of 2fa" do
      user = create(:user, use_two_factor_authentication: true, phone_number: "+18556254225", phone_number_verified: true, use_sms_auth: true)
      login = create(:login, user:, is_reauthentication: true)

      login.update!(authenticated_with_email: true)

      expect(login).to be_reauthentication
      expect(login).to be_complete
    end
  end
end
