# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event::ApplicationSyncToAirtableJob do
  # Stands in for an Airrecord row: records the fields the job writes.
  let(:airrecord) do
    Class.new(Hash) do
      def save = true
      def id = "recTEST123"
    end.new
  end

  before do
    allow_any_instance_of(Event::Application).to receive(:airtable_record).and_return(airrecord)
  end

  it "syncs 'Previously applied?' from previously_applied, not currently_fiscally_sponsored" do
    application = create(:event_application, previously_applied: true, currently_fiscally_sponsored: false)

    described_class.perform_now(application)

    expect(airrecord["Previously applied?"]).to eq("Yes")
    expect(airrecord["Currently fiscally sponsored?"]).to eq("No")
  end

  it "reports 'No' when the applicant hasn't applied before" do
    application = create(:event_application, previously_applied: false, currently_fiscally_sponsored: true)

    described_class.perform_now(application)

    expect(airrecord["Previously applied?"]).to eq("No")
    expect(airrecord["Currently fiscally sponsored?"]).to eq("Yes")
  end
end
