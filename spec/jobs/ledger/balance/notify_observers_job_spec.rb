# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::Balance::NotifyObserversJob do
  include ActiveJob::TestHelper

  it "checks every observer against the ledger's available balance" do
    event = create(:event, :with_positive_balance)
    low = create(:ledger_balance_observer, ledger: event.ledger, amount_cents: event.ledger.available_balance_cents)
    high = create(:ledger_balance_observer, ledger: event.ledger, amount_cents: event.ledger.available_balance_cents + 1)

    expect { described_class.perform_now(ledger_id: event.ledger.id) }
      .to have_enqueued_mail(Ledger::Balance::ObserverMailer, :low_balance).once

    expect(low.reload.notified_at).to be_nil
    expect(high.reload.notified_at).to be_present
  end

  it "does not raise for a deleted ledger" do
    expect { described_class.perform_now(ledger_id: -1) }.not_to raise_error
  end
end
