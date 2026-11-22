# frozen_string_literal: true

require "rails_helper"

# The Receipt Bin's pile. Card locking counts the settled, enforcement-era
# part of the same pile, so the two can never disagree about a charge.
RSpec.describe User, "#card_charges_missing_receipt", type: :model do
  include_context "card locking charges"

  let(:now) { Time.zone.parse("2026-10-10 12:00:00") }

  before { travel_to(now) }

  it "lists a charge on the cardholder's card that still needs a receipt" do
    charge = create_settled_card_charge(user:, settled_at: 1.day.ago)

    expect(user.card_charges_missing_receipt).to contain_exactly(charge)
  end

  it "drops a charge once a receipt is uploaded, or it is marked no/lost" do
    uploaded = create_settled_card_charge(user:, settled_at: 2.days.ago, uploaded_at: 1.day.ago)
    marked = create_settled_card_charge(user:, settled_at: 2.days.ago)
    marked.no_or_lost_receipt!

    expect(user.card_charges_missing_receipt).not_to include(uploaded, marked)
  end

  it "leaves out another cardholder's charges" do
    create_settled_card_charge(user: create(:user), settled_at: 1.day.ago)

    expect(user.card_charges_missing_receipt).to be_empty
  end

  it "leaves out charges on a salary account, which never asks for receipts" do
    create_settled_card_charge(user:, settled_at: 1.day.ago, charge_event: create(:event, plan_type: Event::Plan::SalaryAccount))

    expect(user.card_charges_missing_receipt).to be_empty
  end

  it "is the pile card locking's outstanding charges are drawn from" do
    in_both = create_settled_card_charge(user:, settled_at: 1.day.ago)
    # Settled before enforcement began: in the bin, never on the hook.
    bin_only = create_settled_card_charge(user:, settled_at: Time.zone.parse("2026-07-01"))

    expect(user.card_charges_missing_receipt).to contain_exactly(in_both, bin_only)
    expect(user.card_locking_outstanding_charges).to contain_exactly(in_both)
  end
end
