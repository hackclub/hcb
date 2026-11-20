# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardLocking::MaterializeChargeJob do
  include_context "card locking charges"

  before { travel_to(Time.zone.parse("2026-10-10 12:00:00")) }

  it "materializes card-locking timing for a settled card charge" do
    charge = create_settled_card_charge(user:, settled_at: 1.day.ago)

    described_class.perform_now(ledger_item_id: charge.id)

    charge.reload
    expect(charge.receipt_due_at).to be_present
  end

  # Jobs enqueued before card locking moved onto ledger items name the charge
  # by its HCB code. The sweep materializes those charges, so the job just
  # drops them rather than looking the code up.
  it "ignores a job enqueued before the move, which names the charge by HCB code" do
    charge = create_settled_card_charge(user:, settled_at: 1.day.ago)

    expect { described_class.perform_now(hcb_code_id: charge.hcb_code.id) }.not_to raise_error

    expect(charge.reload.receipt_due_at).to be_nil
  end

  it "does not raise for a missing ledger item id" do
    expect { described_class.perform_now(ledger_item_id: -1) }.not_to raise_error
  end
end
