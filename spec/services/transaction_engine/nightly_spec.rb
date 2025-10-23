# frozen_string_literal: true

require "rails_helper"

RSpec.describe TransactionEngine::Nightly do
  let(:service) { TransactionEngine::Nightly.new }

  it "succeeds" do
    freeze_time do
      stub_request(:get, "https://api.column.com/reporting")
        .with(
          query: {
            from_date: 1.week.ago.to_date,
            to_date: Date.today,
            limit: 100,
            type: "bank_account_transaction"
          }
        )
        .to_return_json(status: 200, body: { reports: [], has_more: false })

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
end
