# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event::RefreshLedgersJob do
  let(:event) { create(:event) }

  it "refreshes the event's ledgers" do
    expect_any_instance_of(Event).to receive(:refresh_ledgers!)

    described_class.perform_now(event_id: event.id)
  end
end
