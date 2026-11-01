# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::Balance::NotifyObserversJob do
  include ActiveJob::TestHelper

  let(:event) { create(:event, :with_positive_balance) }

  def create_member_observer(amount_cents:)
    user = create(:user)
    create(:organizer_position, user:, event:, role: :member)
    create(:ledger_balance_observer, ledger: event.ledger, user:, amount_cents:)
  end

  it "checks every observer against the ledger's available balance" do
    low = create_member_observer(amount_cents: event.ledger.available_balance_cents)
    high = create_member_observer(amount_cents: event.ledger.available_balance_cents + 1)

    expect { described_class.perform_now(ledger_id: event.ledger.id) }
      .to have_enqueued_mail(Ledger::Balance::ObserverMailer, :low_balance).once

    expect(low.reload.notified_at).to be_nil
    expect(high.reload.notified_at).to be_present
  end

  it "does not email a user who has since lost access to the ledger" do
    observer = create_member_observer(amount_cents: event.ledger.available_balance_cents + 1)
    OrganizerPosition.find_by!(user: observer.user, event:).destroy!

    expect { described_class.perform_now(ledger_id: event.ledger.id) }
      .not_to have_enqueued_mail(Ledger::Balance::ObserverMailer, :low_balance)
    expect(observer.reload.notified_at).to be_nil
  end

  it "does not raise for a deleted ledger" do
    expect { described_class.perform_now(ledger_id: -1) }.not_to raise_error
  end
end
