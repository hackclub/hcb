# frozen_string_literal: true

require "rails_helper"

RSpec.describe TransactionEngine::NightlyJob, type: :job do
  let(:transaction_engine) { instance_double(TransactionEngine::Nightly) }
  let(:event_mapping_engine) { instance_double(EventMappingEngine::Nightly) }
  let(:events) { [] }

  before do
    allow(TransactionEngine::Nightly).to receive(:new).and_return(transaction_engine)
    allow(EventMappingEngine::Nightly).to receive(:new).and_return(event_mapping_engine)
    allow(event_mapping_engine).to receive(:run) { events << :map_events }
    allow(Appsignal::CheckIn).to receive(:cron) { |identifier| events << [:check_in, identifier] }
  end

  it "checks in once transactions are imported and mapped" do
    allow(transaction_engine).to receive(:run) { events << :import }

    described_class.perform_now

    expect(events).to eq([:import, :map_events, [:check_in, "transaction_engine_nightly_job"]])
  end

  it "doesn't check in when the run fails" do
    allow(transaction_engine).to receive(:run).and_raise(StandardError)

    expect { described_class.perform_now }.to raise_error(StandardError)

    expect(events).to be_empty
  end
end
