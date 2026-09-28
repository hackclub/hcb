# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event::Application, type: :model do
  describe "#schedule_airtable_sync" do
    let!(:application) { create(:event_application) }

    it "enqueues a sync job on save" do
      expect {
        application.update!(name: "Updated Name")
      }.to have_enqueued_job(Event::ApplicationSyncToAirtableJob).with(application)
    end

    context "when the job runs after a save" do
      let!(:application) { create(:event_application, aasm_state: "submitted") }

      before do
        fake_record = double("airtable_record")
        allow(fake_record).to receive(:[]=)
        allow(fake_record).to receive(:[]).and_return(nil)
        allow(fake_record).to receive(:save)
        allow(fake_record).to receive(:id).and_return("recABC123")
        allow(ApplicationsTable).to receive(:all).and_return([fake_record])
      end

      it "only runs the sync job once, preventing an infinite loop" do
        perform_enqueued_jobs do
          application.update!(name: "Changed")
        end

        syncs_performed = performed_jobs.count { |j| j[:job] == Event::ApplicationSyncToAirtableJob }
        expect(syncs_performed).to eq(1)
      end
    end
  end

  describe "#activate_event!" do
    it "creates an event using the application's description as the mission statement" do
      user = create(:user)
      application = create(:event_application, user:, description: "Run the best hackathon")

      allow(User).to receive(:system_user).and_return(create(:user, :make_admin, email: User::SYSTEM_USER_EMAIL))
      allow_any_instance_of(Contract::Party).to receive(:sync_with_docuseal)

      Contract::FiscalSponsorship.create!(contractable: application, include_videos: false)

      # The application caches `contract` (nil) while it's being created and
      # never notices the contract issued afterwards, so reload to pick it up.
      application.reload
      contract = application.contract
      contract.parties.create!(user:, role: :signee)
      contract.update_column(:aasm_state, "signed")

      allow_any_instance_of(Contract::FiscalSponsorship).to receive(:create_document!)
      invite = double("invite", accept: true)
      create_service = double("organizer position invite create service", model: invite, run!: true)
      allow(OrganizerPositionInviteService::Create).to receive(:new).and_return(create_service)
      allow(application).to receive(:set_airtable_status).with("Onboarded")

      application.activate_event!(risk_level: :zero)

      expect(application.reload.event.description).to eq("Run the best hackathon")
    end
  end
end
