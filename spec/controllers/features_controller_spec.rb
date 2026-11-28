# frozen_string_literal: true

require "rails_helper"

RSpec.describe FeaturesController do
  include SessionSupport
  render_views

  describe "requiring two-factor authentication for an organization" do
    let(:event) { create(:event) }

    it "lets a contract signee with two-factor authentication turn it on and emails the team" do
      signee = create(:user, :with_two_factor_authentication)
      create(:organizer_position, event:, user: signee, role: :manager, is_signee: true)
      member = create(:organizer_position, event:, role: :member).user
      create_session(signee, verified: true)

      signee_mail = have_enqueued_mail(EventMailer, :two_factor_authentication_required).with(params: { event:, user: signee, whodunnit: signee }, args: [])
      member_mail = have_enqueued_mail(EventMailer, :two_factor_authentication_required).with(params: { event:, user: member, whodunnit: signee }, args: [])

      expect {
        PublicActivity.with_tracking { post(:enable_feature, params: { feature: :require_two_factor_authentication_2026_11_24, event_id: event.id }) }
      }.to signee_mail.and(member_mail)

      expect(response).to redirect_to(edit_event_path(event, tab: :features))
      expect(Flipper.enabled?(:require_two_factor_authentication_2026_11_24, event)).to eq(true)
      expect(PublicActivity::Activity.where(key: "event.two_factor_authentication_required", trackable: event, owner: signee)).to exist
    end

    it "does nothing when the requirement is already on" do
      signee = create(:user, :with_two_factor_authentication)
      create(:organizer_position, event:, user: signee, role: :manager, is_signee: true)
      create(:organizer_position, event:, role: :member)
      Flipper.enable_actor(:require_two_factor_authentication_2026_11_24, event)
      create_session(signee, verified: true)

      expect {
        PublicActivity.with_tracking { post(:enable_feature, params: { feature: :require_two_factor_authentication_2026_11_24, event_id: event.id }) }
      }.not_to have_enqueued_mail(EventMailer, :two_factor_authentication_required)

      expect(response).to redirect_to(edit_event_path(event, tab: :features))
      expect(flash[:info]).to eq("Two-factor authentication is already required for #{event.name}.")
      expect(PublicActivity::Activity.where(key: "event.two_factor_authentication_required", trackable: event)).not_to exist
    end

    it "can't be attached to a user" do
      user = create(:user)
      create_session(user, verified: true)

      post(:enable_feature, params: { feature: :require_two_factor_authentication_2026_11_24 })

      expect(response).to redirect_to(settings_previews_path)
      expect(flash[:error]).to eq("Sorry, this feature flag doesn't currently exist.")
      expect(Flipper.enabled?(:require_two_factor_authentication_2026_11_24, user)).to eq(false)
    end

    it "refuses a signee who doesn't use two-factor authentication themselves" do
      signee = create(:user)
      create(:organizer_position, event:, user: signee, role: :manager, is_signee: true)
      create_session(signee, verified: true)

      expect {
        post(:enable_feature, params: { feature: :require_two_factor_authentication_2026_11_24, event_id: event.id })
      }.not_to have_enqueued_mail(EventMailer, :two_factor_authentication_required)

      expect(flash[:error]).to eq("You are not authorized to perform this action.")
      expect(Flipper.enabled?(:require_two_factor_authentication_2026_11_24, event)).to eq(false)
    end

    it "refuses a manager who isn't a contract signee" do
      manager = create(:user, :with_two_factor_authentication)
      create(:organizer_position, event:, user: manager, role: :manager)
      create_session(manager, verified: true)

      post(:enable_feature, params: { feature: :require_two_factor_authentication_2026_11_24, event_id: event.id })

      expect(flash[:error]).to eq("You are not authorized to perform this action.")
      expect(Flipper.enabled?(:require_two_factor_authentication_2026_11_24, event)).to eq(false)
    end

    it "holds turning it off to the same bar" do
      Flipper.enable_actor(:require_two_factor_authentication_2026_11_24, event)
      manager = create(:user, :with_two_factor_authentication)
      create(:organizer_position, event:, user: manager, role: :manager)
      create_session(manager, verified: true)

      post(:disable_feature, params: { feature: :require_two_factor_authentication_2026_11_24, event_id: event.id })

      expect(flash[:error]).to eq("You are not authorized to perform this action.")
      expect(Flipper.enabled?(:require_two_factor_authentication_2026_11_24, event)).to eq(true)
    end

    it "lets a contract signee with two-factor authentication turn it off" do
      Flipper.enable_actor(:require_two_factor_authentication_2026_11_24, event)
      signee = create(:user, :with_two_factor_authentication)
      create(:organizer_position, event:, user: signee, role: :manager, is_signee: true)
      create_session(signee, verified: true)

      expect {
        PublicActivity.with_tracking { post(:disable_feature, params: { feature: :require_two_factor_authentication_2026_11_24, event_id: event.id }) }
      }.not_to have_enqueued_mail(EventMailer, :two_factor_authentication_required)

      expect(response).to redirect_to(edit_event_path(event, tab: :features))
      expect(flash[:success]).to eq("Two-factor authentication is no longer required for #{event.name}.")
      expect(flash[:error]).to be_nil
      expect(Flipper.enabled?(:require_two_factor_authentication_2026_11_24, event)).to eq(false)
      expect(PublicActivity::Activity.where(key: "event.two_factor_authentication_unrequired", trackable: event, owner: signee)).to exist
    end
  end

  describe "#disable_feature" do
    it "requires sudo mode to disable sudo mode" do
      user = create(:user)
      Flipper.enable(:sudo_mode_2015_07_21, user)
      create_session(user, verified: true)

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
      expect(flash[:success]).to eq("You've opted out of this beta; please let us know if you had any feedback.")
      expect(flash[:error]).to be_nil
      expect(Flipper.enabled?(:sudo_mode_2015_07_21, user)).to eq(false)
    end
  end
end
