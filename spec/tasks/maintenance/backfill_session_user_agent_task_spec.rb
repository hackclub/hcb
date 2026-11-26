# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::BackfillSessionUserAgentTask, versioning: true do
  def complete_with_email(login, user_agent: "fake firefox")
    login_code = create(:login_code, user: login.user)
    service = ProcessLoginService.new(login:, ip_address: "127.0.0.1", user_agent:)
    expect(service.process_login_code(code: login_code.code, sms: false)).to be(true)
  end

  def attach_session(login, **attrs)
    create(:user_session, user: login.user, **attrs).tap do |session|
      login.update!(user_session: session)
    end
  end

  describe ".collection" do
    it "collects recent sessions without a user agent whose login has a succeeded email attempt" do
      login = create(:login)
      complete_with_email(login)
      session = attach_session(login)

      expect(described_class.collection).to contain_exactly(session)
    end

    it "skips sessions that already have a user agent" do
      login = create(:login)
      complete_with_email(login)
      attach_session(login, user_agent: "already there")

      expect(described_class.collection).to be_empty
    end

    it "skips sessions older than the metadata retention window" do
      login = create(:login)
      complete_with_email(login)
      attach_session(login, created_at: 18.months.ago - 1.day)

      expect(described_class.collection).to be_empty
    end

    it "skips sessions whose login never succeeded with an email code" do
      login = create(:login)
      login.update!(authenticated_with_webauthn: true)
      attach_session(login)

      expect(described_class.collection).to be_empty
    end
  end

  describe ".process" do
    it "copies the user agent of the email attempt that completed the login" do
      login = create(:login)
      complete_with_email(login)
      session = attach_session(login)

      described_class.process(session)

      expect(session.reload.user_agent).to eq("fake firefox")
    end

    it "copies it when the email code was the second of two factors" do
      user = create(:user, use_two_factor_authentication: true, phone_number: "+18556254225", phone_number_verified: true)
      login = create(:login, user:)
      login.update!(authenticated_with_sms: true)
      expect(login).not_to be_complete
      complete_with_email(login)
      expect(login.reload).to be_complete
      session = attach_session(login)

      described_class.process(session)

      expect(session.reload.user_agent).to eq("fake firefox")
    end

    it "leaves the session alone when another factor completed the login after the email code" do
      user = create(:user, use_two_factor_authentication: true, phone_number: "+18556254225", phone_number_verified: true)
      login = create(:login, user:)
      complete_with_email(login)
      expect(login.reload).not_to be_complete
      login.update!(authenticated_with_sms: true)
      expect(login.reload).to be_complete
      session = attach_session(login)

      described_class.process(session)

      expect(session.reload.user_agent).to be_nil
    end

    it "ignores reauthentication logins attached to the same session" do
      login = create(:login)
      complete_with_email(login)
      session = attach_session(login)
      reauthentication = create(:login, user: login.user, is_reauthentication: true)
      complete_with_email(reauthentication, user_agent: "later browser")
      reauthentication.update!(user_session: session)

      described_class.process(session)

      expect(session.reload.user_agent).to eq("fake firefox")
    end

    it "leaves the session alone when the attempt has no user agent" do
      login = create(:login)
      complete_with_email(login, user_agent: nil)
      session = attach_session(login)

      described_class.process(session)

      expect(session.reload.user_agent).to be_nil
    end
  end
end
