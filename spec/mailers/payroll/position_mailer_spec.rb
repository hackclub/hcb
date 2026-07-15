# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payroll::PositionMailer, type: :mailer do
  describe "#onboarding" do
    let(:manager) { create(:user, email: "manager@example.invalid") }
    let(:event) { create(:event, organizers: [manager]) }
    let(:payee) { create(:payee, event:) }
    let(:position) { create(:payroll_position, payee:) }
    let(:creator) { create(:user, email: "creator@example.invalid") }

    before do
      allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))

      stub_request(:post, "https://api.docuseal.co/submissions")
        .to_return(status: 201, body: [{ submission_id: "STUBBED" }].to_json, headers: { content_type: "application/json" })
      stub_request(:get, "https://api.docuseal.co/submissions/STUBBED")
        .to_return(
          status: 200,
          body: { submitters: [{ role: "HCB", slug: "hcb-slug" }, { role: "Organizer", slug: "organizer-slug" }, { role: "Contractor", slug: "contractor-slug" }] }.to_json,
          headers: { content_type: "application/json" }
        )

      position.send_contract(organizer_user: creator)
    end

    it "sets reply_to to the event's managers and the position's creator" do
      mail = described_class.with(position:).onboarding

      expect(mail.reply_to).to include("manager@example.invalid", "creator@example.invalid")
    end
  end
end
