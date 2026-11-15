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

  describe "cron check-in" do
    let(:events) { [] }

    before do
      allow(Appsignal::CheckIn).to receive(:cron) { |identifier| events << [:check_in, identifier] }
    end

    it "checks in once the run finishes" do
      allow(nightly).to receive(:run) { events << :run }

      described_class.perform_now

      expect(events).to eq([:run, [:check_in, "pending_transaction_engine_nightly_job"]])
    end

    it "doesn't check in when the run fails" do
      allow(nightly).to receive(:run).and_raise(StandardError)

      described_class.perform_now

      expect(events).to be_empty
    end
  end
end
