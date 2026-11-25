# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventMailer, type: :mailer do
  describe "#two_factor_authentication_required" do
    let(:event) { create(:event, name: "Hack Club HQ") }
    let(:whodunnit) { create(:user, full_name: "Signee McSignface") }

    before do
      allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
      create(:organizer_position, event:, user: whodunnit, role: :manager, is_signee: true)
      Flipper.enable_actor(:require_two_factor_authentication_2026_11_24, event)
      enabled_at = Time.zone.parse("2026-11-24 12:00:00")
      Flipper::Adapters::ActiveRecord::Gate.create!(feature_key: "require_two_factor_authentication_2026_11_24", key: "actors", value: event.flipper_id, created_at: enabled_at, updated_at: enabled_at)
    end

    context "for a member without two-factor authentication" do
      let(:user) { create(:user, full_name: "Member McMemberface") }
      let(:mail) { described_class.with(event:, user:, whodunnit:).two_factor_authentication_required }

      it "asks them to enable it by the deadline" do
        expect(mail.to).to eq([user.email])
        expect(mail.subject).to eq("[Action Needed] Enable two-factor authentication for Hack Club HQ")
        expect(mail.body.encoded).to include("Signee McSignface")
        expect(mail.body.encoded).to include("You don't have two-factor authentication enabled yet.")
        expect(mail.body.encoded).to include("December 1st")
        expect(mail.body.encoded).to include(settings_security_url)
        expect(mail.body.encoded).not_to include("nothing you need to do")
      end
    end

    context "for a member who already uses two-factor authentication" do
      let(:user) { create(:user, :with_two_factor_authentication) }
      let(:mail) { described_class.with(event:, user:, whodunnit:).two_factor_authentication_required }

      it "tells them nothing is needed" do
        expect(mail.subject).to eq("Hack Club HQ now requires two-factor authentication")
        expect(mail.body.encoded).to include("nothing you need to do")
        expect(mail.body.encoded).not_to include("December 1st")
      end
    end
  end
end
