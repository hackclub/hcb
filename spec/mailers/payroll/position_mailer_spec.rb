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
      party = position.contracts.first.party(:contractor)
      mail = described_class.with(position:, party:).onboarding

      expect(mail.reply_to).to include("manager@example.invalid", "creator@example.invalid")
    end

    describe "#onboarding_reminder" do
      it "is addressed to the contractor and points to the onboarding page" do
        mail = described_class.with(position:).onboarding_reminder

        expect(mail.to).to include(payee.email)
        expect(mail.subject).to include(event.name)
        expect(mail.reply_to).to include("manager@example.invalid", "creator@example.invalid")
        expect(mail.body.encoded).to include("payroll_positions/#{position.hashid}")
      end

      it "goes to the legal entity's users when the contractor has an account" do
        legal_entity_user = create(:user, email: "contractor@example.invalid")
        payee.legal_entity.users << legal_entity_user

        mail = described_class.with(position:).onboarding_reminder

        expect(mail.to).to include("contractor@example.invalid")
      end
    end
  end

  describe "renewals" do
    let(:event) { create(:event) }
    let(:payee) { create(:payee, event:) }
    let(:position) do
      create(:payroll_position, payee:, aasm_state: "onboarded", onboarded_at: 1.month.ago,
                                start_date: 1.month.ago.to_date, end_date: 2.months.from_now.to_date)
    end
    let(:renewal) { position.build_renewal.tap(&:save!) }

    it "asks the contractor to sign the renewal, noting they can keep invoicing until the current contract ends" do
      mail = described_class.with(position: renewal).onboarding

      expect(mail.subject).to eq("[Action Required] Sign your renewed contract with #{event.name}")
      expect(mail.body.encoded).to include(position.end_date.to_fs(:long))
    end

    it "tells organizers the contract was renewed once it's signed" do
      mail = described_class.with(position: renewal).onboarded

      expect(mail.subject).to eq("#{payee.display_name}'s contract with #{event.name} has been renewed")
    end

    it "tells the contractor a canceled renewal leaves their current contract in place" do
      mail = described_class.with(position: renewal).terminated

      expect(mail.subject).to eq("The renewal of your contract with #{event.name} has been canceled")
      expect(mail.body.encoded).to include("Your current contract is unaffected")
    end
  end
end
