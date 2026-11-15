# frozen_string_literal: true

require "rails_helper"

RSpec.describe PendingTransactionEngine::NightlyJob, type: :job do
  let(:nightly) { instance_double(PendingTransactionEngine::Nightly) }

  before do
    allow(PendingTransactionEngine::Nightly).to receive(:new).and_return(nightly)
    allow(Rails.error).to receive(:report)
  end

  it "discards and reports application errors" do
    error = StandardError.new("Stripe is unavailable")
    allow(nightly).to receive(:run).and_raise(error)

    expect { described_class.perform_now }.not_to raise_error

    expect(Rails.error).to have_received(:report).with(error)
  end

  it "re-raises Sidekiq::Shutdown without reporting it" do
    allow(nightly).to receive(:run).and_raise(Sidekiq::Shutdown)

    expect { described_class.perform_now }.to raise_error(Sidekiq::Shutdown)

    expect(Rails.error).not_to have_received(:report)
  end
end
