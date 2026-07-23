# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::BackfillCardLockingTimingTask do
  include_context "card locking charges"

  before { travel_to(Time.zone.parse("2026-10-10 12:00:00")) }

  it "sets card_charge_settled_at and receipt_due_at for an outstanding charge" do
    hcb_code = create_settled_card_charge(user:, settled_at: 3.days.ago)

    described_class.new.process(hcb_code)

    expect(hcb_code.reload.card_charge_settled_at).to be_present
    expect(hcb_code.reload.receipt_due_at).to be_present
  end

  it "sets receipt_resolved_at for a resolved charge" do
    hcb_code = create_settled_card_charge(user:, settled_at: 20.days.ago, uploaded_at: 19.days.ago)

    described_class.new.process(hcb_code)

    expect(hcb_code.reload.receipt_resolved_at).to be_present
  end
end
