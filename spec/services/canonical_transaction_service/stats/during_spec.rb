# frozen_string_literal: true

require "rails_helper"

RSpec.describe CanonicalTransactionService::Stats::During do
  let(:event_1) { create(:event) }
  let(:event_2) { create(:event) }
  let(:event_3) {
    event = create(:event)
    event.plan.update(type: Event::Plan::HackClubAffiliate)
    event.reload
  }

  it "returns stats related to events transactions" do
    # Omitted because event is omitting stats
    create(:canonical_transaction, event: event_3, amount_cents: 250)
    # Omitted because outside of date range
    create(:canonical_transaction, event: event_1, amount_cents: 125, date: Date.parse("2018-01-01"))

    # Raised
    create(:canonical_transaction, event: event_1, amount_cents: 2000)
    create(:canonical_transaction, event: event_2, amount_cents: 500)

    # Revenue
    tx = create(:canonical_transaction, amount_cents: 1000)
    canonical_event_mapping = create(:canonical_event_mapping, canonical_transaction: tx, event: event_1)
    create(:fee, amount_cents_as_decimal: 1000, canonical_event_mapping: )

    # Expenses
    create(:canonical_transaction, event: event_2, amount_cents: -100)

    start_time = Date.parse("2019-01-01")
    end_time = Date.today

    result = described_class.new(start_time:, end_time:).run

    expected = { transactions_volume: 3600,
                 expenses: -100,
                 raised: 3500,
                 revenue: 1000,
                 size: { total: 4, raised: 3, expenses: 1 },
                 start_time: start_time.to_datetime,
                 end_time: end_time.to_datetime
}
    expect(result).to eq(expected)
  end
end
