# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event::TerminationRequestMailer, type: :mailer do
  let(:event) { create(:event, name: "Lion City Hacks") }
  let(:signee) { create(:user, full_name: "Orpheus Dinosaur") }
  let(:termination_request) { create(:event_termination_request, event:, requested_by: signee, reason: "The hackathon is over.") }

  describe "#notify_operations" do
    let(:mail) { described_class.with(termination_request:).notify_operations }

    it "goes to operations with the requester, organization and reason" do
      expect(mail.to).to eq([ApplicationMailer::OPERATIONS_EMAIL])
      expect(mail.subject).to eq("Orpheus Dinosaur is requesting the termination of Lion City Hacks")
      expect(mail.body.encoded).to include("The hackathon is over.")
      expect(mail.body.encoded).to include(admin_termination_request_url(termination_request))
    end
  end

  describe "#confirmation" do
    let(:mail) { described_class.with(termination_request:).confirmation }

    it "goes to the requester" do
      expect(mail.to).to eq([signee.email])
      expect(mail.subject).to eq("We've received your request to terminate Lion City Hacks")
      expect(mail.body.encoded).to include(edit_event_url(event, tab: "details"))
    end
  end
end
