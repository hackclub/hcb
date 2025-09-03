# frozen_string_literal: true

require "rails_helper"

RSpec.describe TransactionEngine::Nightly do
  let(:service) { TransactionEngine::Nightly.new }

  it "succeeds" do
    expect(service).to receive(:import_raw_plaid_transactions!).and_return(true)
    expect(service).to receive(:import_raw_stripe_transactions!).and_return(true)
    expect(service).to receive(:import_raw_csv_transactions!).and_return(true)

    expect(service).to receive(:hash_raw_plaid_transactions!).and_return(true)
    expect(service).to receive(:hash_raw_stripe_transactions!).and_return(true)
    expect(service).to receive(:hash_raw_csv_transactions!).and_return(true)

    expect(service).to receive(:canonize_hashed_transactions!).and_return(true)

    expect(service).to receive(:fix_plaid_mistakes!).and_return(true)

    expect(service).to receive(:fix_memo_mistakes!).and_return(true)

    service.run
  end
end
