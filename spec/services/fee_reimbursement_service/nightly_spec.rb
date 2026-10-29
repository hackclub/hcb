# frozen_string_literal: true

require "rails_helper"

RSpec.describe FeeReimbursementService::Nightly do
  # The group's ledger item is mapped to the Hack Club Bank event, which must exist.
  let!(:hack_club_bank) { create(:event, id: EventMappingEngine::EventIds::HACK_CLUB_BANK) }

  before do
    # StripeTopup calls the Stripe API on create; each top-up needs its own id.
    stub_request(:post, "https://api.stripe.com/v1/topups")
      .to_return { { status: 200, body: { id: "tu_#{SecureRandom.hex(4)}" }.to_json, headers: {} } }
  end

  let(:this_week) { Time.now.strftime(FeeReimbursementGroup::WEEK_FORMAT) }

  it "tops up each fee reimbursement under this week's group" do
    first = create(:fee_reimbursement, amount: 1_23)
    second = create(:fee_reimbursement, amount: 4_56)

    expect { described_class.new.run }.to change(FeeReimbursementGroup, :count).by(1).and change(StripeTopup, :count).by(2)

    group = FeeReimbursementGroup.find_by!(slug: this_week)
    expect(group.fee_reimbursements).to contain_exactly(first, second)
    expect(group.ledger_item.status).to eq("intended")

    first.reload
    expect(first.processed_at).to be_present
    expect(first.stripe_topup.amount_cents).to eq(1_23)
    expect(first.stripe_topup.description).to eq("Fee reimbursement ##{first.id}")
    expect(first.stripe_topup.metadata).to eq("fee_reimbursement_id" => first.id)

    # Both top-ups carry the group's short code, which their bank debits will be matched on.
    expect(StripeTopup.distinct.pluck(:statement_descriptor)).to eq(["HCB-#{group.local_hcb_code.short_code}"])
  end

  it "reuses this week's existing group" do
    group = create(:fee_reimbursement_group, slug: this_week)
    fee_reimbursement = create(:fee_reimbursement)

    expect { described_class.new.run }.not_to change(FeeReimbursementGroup, :count)

    expect(fee_reimbursement.reload.fee_reimbursement_group).to eq(group)
    expect(fee_reimbursement.stripe_topup.statement_descriptor).to eq("HCB-#{group.local_hcb_code.short_code}")
  end

  it "marks a zero-amount fee reimbursement processed without a top-up or group" do
    fee_reimbursement = create(:fee_reimbursement, amount: 0)

    expect { described_class.new.run }.not_to change(StripeTopup, :count)
    expect(FeeReimbursementGroup.count).to eq(0)

    fee_reimbursement.reload
    expect(fee_reimbursement.processed_at).to be_present
    expect(fee_reimbursement.fee_reimbursement_group).to be_nil
  end

  it "skips fee reimbursements that are already processed" do
    create(:fee_reimbursement, processed_at: 1.day.ago)

    expect { described_class.new.run }.not_to change(StripeTopup, :count)
  end
end
