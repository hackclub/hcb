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
end
