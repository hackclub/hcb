# frozen_string_literal: true

require "rails_helper"

RSpec.describe User::Session, type: :model do
  it "is valid" do
    user_session = create(:user_session)
    expect(user_session).to be_valid
  end

  it "can be searched by session_token" do
    token = SecureRandom.urlsafe_base64
    user_session = create(:user_session, session_token: token)
    expect(User::Session.find_by(session_token: token)).to eq(user_session)
  end

  context "when user is locked" do
    it "can't be created" do
      user = create(:user, locked_at: Time.now)
      expect { create(:user_session, user:) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "can be be created when impersonated" do
      user = create(:user, locked_at: Time.now)
      admin_user = create(:user, access_level: :admin)
      user_session = create(:user_session, user:, impersonated_by: admin_user)
      expect(user_session).to be_valid
    end
  end

  describe "#sudo_mode?" do
    it "returns true unless the user has the feature flag enabled" do
      user_session = create(:user_session)

      expect(user_session).to be_sudo_mode
    end

    it "returns false if there are no associated logins" do
      user_session = create(:user_session)
      Flipper.enable(:sudo_mode_2015_07_21, user_session.user)

      expect(user_session).not_to be_sudo_mode
    end

    it "returns true if the most recently created login is less than 2 hours old" do
      freeze_time do
        user = create(:user)
        Flipper.enable(:sudo_mode_2015_07_21, user)
        user_session = create(:user_session, user:)
        _initial_login = create(
          :login,
          user:,
          user_session:,
          aasm_state: "complete",
          authenticated_with_email: true,
          created_at: 2.hours.ago - 1.second,
        )

        expect(user_session).not_to be_sudo_mode

        _login = create(
          :login,
          is_reauthentication: true,
          user:,
          user_session:,
          aasm_state: "complete",
          authenticated_with_email: true,
          created_at: 2.hours.ago
        )

        expect(user_session).to be_sudo_mode
      end
    end
  end

  describe "#last_reauthenticated_at" do
    it "returns nil if there was only an initial login" do
      user_session = create(:user_session)
      initial_login = create(:login, user: user_session.user, authenticated_with_email: true)
      initial_login.update!(user_session:)

      expect(user_session.last_reauthenticated_at).to be_nil
    end

    it "returns the latest reauthentication time" do
      user_session = create(:user_session)
      initial_login = create(:login, user: user_session.user, authenticated_with_email: true)
      initial_login.update!(user_session:)

      travel(1.hour)
      reauth1 = create(:login, user: user_session.user, authenticated_with_email: true, is_reauthentication: true)
      reauth1.update!(user_session:)

      travel(1.hour)
      reauth2 = create(:login, user: user_session.user, authenticated_with_email: true, is_reauthentication: true)
      reauth2.update!(user_session:)

      expect(user_session.last_reauthenticated_at).to eq(reauth2.created_at)
    end
  end

  describe "public activity" do
    specify "new sessions are tracked in public activity" do
      user = create(:user, full_name: "Hack Clubber")

      PublicActivity.with_tracking do
        create(:user_session, user:)
      end

      activity = PublicActivity::Activity.sole
      rendered = rendered_text(activity.render(ApplicationController.renderer, current_user: user))
      expect(rendered).to eq("You logged into HCB less than a minute ago")
    end

    specify "impersonated sessions are only rendered to admins" do
      admin = create(:user, :make_admin, full_name: "Orpheus the Dinosaur")
      user = create(:user, full_name: "Hack Clubber")

      PublicActivity.with_tracking do
        create(:user_session, user:, impersonated_by: admin)
      end

      activity = PublicActivity::Activity.sole
      user_rendered = rendered_text(activity.render(ApplicationController.renderer, current_user: user))
      expect(user_rendered).to eq("")

      activity = PublicActivity::Activity.sole
      admin_rendered = rendered_text(activity.render(ApplicationController.renderer, current_user: admin))
      expect(admin_rendered).to eq("You impersonated Hack Clubber on HCB less than a minute ago")
    end

    def rendered_text(raw_html)
      Nokogiri::HTML5
        .fragment(raw_html)
        .text
        .squish
    end
  end
end
