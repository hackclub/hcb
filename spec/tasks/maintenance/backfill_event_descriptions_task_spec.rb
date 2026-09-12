# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::BackfillEventDescriptionsTask do
  let(:task) { described_class.new }

  describe "#collection" do
    it "includes application-less events with a blank description" do
      event = create(:event, description: nil)

      expect(task.collection).to include(event)
    end

    it "excludes events whose description is already set" do
      event = create(:event, description: "Already populated")

      expect(task.collection).not_to include(event)
    end

    it "excludes events that have an application" do
      event = create(:event, description: nil)
      create(:event_application, event:, description: "Run the best hackathon")

      expect(task.collection).not_to include(event)
    end
  end

  describe "#process" do
    it "fills the description from the event's Airtable record" do
      event = create(:event, description: nil)
      fake_record = double("airtable_record")
      allow(fake_record).to receive(:[]).with("Tell us about your event").and_return("Run the best hackathon")
      allow(ApplicationsTable).to receive(:all).and_return([fake_record])

      task.process(event)

      expect(event.reload.description).to eq("Run the best hackathon")
    end

    it "leaves events without an Airtable description untouched" do
      event = create(:event, description: nil)
      allow(ApplicationsTable).to receive(:all).and_return([])

      task.process(event)

      expect(event.reload.description).to be_nil
    end

    it "does not crash when Airtable is unreachable" do
      event = create(:event, description: nil)
      allow(ApplicationsTable).to receive(:all).and_raise(Airrecord::Error, "boom")

      expect { task.process(event) }.not_to raise_error

      expect(event.reload.description).to be_nil
    end
  end
end
