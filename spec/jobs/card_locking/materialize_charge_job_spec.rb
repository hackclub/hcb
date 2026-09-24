# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardLocking::MaterializeChargeJob do
  include_context "card locking charges"

  before { travel_to(Time.zone.parse("2026-10-10 12:00:00")) }

  it "materializes card-locking timing for a settled card charge" do
    hc = create_settled_card_charge(user:, settled_at: 1.day.ago)

    described_class.perform_now(hcb_code_id: hc.id)

    hc.reload
    expect(hc.card_charge_settled_at).to be_present
    expect(hc.receipt_due_at).to be_present
  end

  it "does not raise for a missing hcb_code id" do
    expect { described_class.perform_now(hcb_code_id: -1) }.not_to raise_error
  end
end
