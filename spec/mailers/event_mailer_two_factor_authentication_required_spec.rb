# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventMailer, type: :mailer do
  describe "#two_factor_authentication_required" do
    let(:event) { create(:event, name: "Hack Club HQ") }
    let(:whodunnit) { create(:user, full_name: "Signee McSignface") }
    let(:deadline) { Time.zone.parse("2026-12-01 12:00:00 UTC") }

    before do
      create(:organizer_position, event:, user: whodunnit, role: :manager, is_signee: true)
    end

    context "for a member without two-factor authentication" do
      let(:user) { create(:user, full_name: "Member McMemberface") }
      let(:mail) { described_class.with(event:, user:, whodunnit:, deadline:).two_factor_authentication_required }

      it "asks them to enable it by the deadline, in their own time zone" do
        allow(user).to receive(:assumed_timezone).and_return("America/New_York")

        expect(mail.to).to eq([user.email])
        expect(mail.subject).to eq("[Action Required] Enable two-factor authentication to keep access to Hack Club HQ")
        expect(mail.body.encoded).to include("Hi Member,")
        expect(mail.body.encoded).to include("Signee McSignface (a contract signee)")
        expect(mail.body.encoded).to include("You don't have two-factor authentication enabled yet.")
        expect(mail.body.encoded).to include("December 1, 2026 at 7:00 AM EST")
        expect(mail.body.encoded).to include('click "Update preferences"')
        expect(mail.body.encoded).to include(settings_security_url)
        expect(mail.body.encoded).not_to include("nothing you need to do")
      end

      it "describes the sender as an HCB admin when they aren't a signee" do
        mail = described_class.with(event:, user:, whodunnit: create(:user, :make_admin, full_name: "Admin McAdminface"), deadline:).two_factor_authentication_required

        expect(mail.body.encoded).to include("Admin McAdminface (an HCB admin)")
      end

      it "greets a member without a parsable first name by their display name" do
        allow(user).to receive(:first_name).and_return(nil)

        expect(mail.body.encoded).to include("Hi #{user.name},")
        expect(mail.body.encoded).not_to include("Hi ,")
      end
    end

    context "for a member who already uses two-factor authentication" do
      let(:user) { create(:user, :with_two_factor_authentication) }
      let(:mail) { described_class.with(event:, user:, whodunnit:, deadline:).two_factor_authentication_required }

      it "tells them nothing is needed" do
        expect(mail.subject).to eq("Hack Club HQ now requires two-factor authentication")
        expect(mail.body.encoded).to include("nothing you need to do")
        expect(mail.body.encoded).not_to include("December 1, 2026")
      end
    end

    it "is enqueued with the deadline from when the requirement was turned on" do
      require_two_factor_authentication!(event, at: Time.zone.parse("2026-11-24 12:00:00"))
      member = create(:organizer_position, event:).user

      expect {
        event.notify_two_factor_authentication_required(whodunnit:)
      }.to have_enqueued_mail(EventMailer, :two_factor_authentication_required).with(params: { event:, user: member, whodunnit:, deadline: Time.zone.parse("2026-12-01 12:00:00") }, args: [])
    end
  end
end
