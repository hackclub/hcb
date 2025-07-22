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
      user = create(:user, use_two_factor_authentication: true)
      login = create(:login, user:)

      login.update!(authenticated_with_email: true)

      expect(login).not_to be_complete
    end

    it "is true when 2fa is enabled and two factors were used" do
      user = create(:user, use_two_factor_authentication: true)
      login = create(:login, user:)

      login.update!(authenticated_with_email: true)
      login.update!(authenticated_with_totp: true)

      expect(login).to be_complete
    end

    it "is true when the login is a reauthentication and one factor was used regardless of 2fa" do
      user = create(:user, use_two_factor_authentication: true)
      initial_login = create(:login, user:)
      login = create(:login, user:, initial_login:)

      login.update!(authenticated_with_email: true)

      expect(login).to be_reauthentication
      expect(login).to be_complete
    end
  end

  describe "#reauthentication?" do
    it "is false by default" do
      login = create(:login)

      expect(login).not_to be_reauthentication
    end

    it "is true when there is an initial login" do
      user = create(:user)
      initial_login = create(:login, user:)
      login = create(:login, user:, initial_login:)

      expect(login).to be_reauthentication
    end
  end
end
