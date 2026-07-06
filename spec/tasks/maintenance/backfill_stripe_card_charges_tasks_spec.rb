# frozen_string_literal: true

require "rails_helper"

RSpec.describe "StripeCardCharge backfill tasks" do
  it "links pre-existing raw transactions into a single charge" do
    rpst = create(:raw_pending_stripe_transaction, stripe_transaction_id: "iauth_backfill")
    rst = create(:raw_stripe_transaction, stripe_authorization_id: "iauth_backfill")

    # simulate records that predate the StripeCardCharge model
    StripeCardCharge.delete_all

    Maintenance::BackfillPendingStripeCardChargesTask.new.process(rpst.reload)
    Maintenance::BackfillSettledStripeCardChargesTask.new.process(rst.reload)

    charge = rpst.reload.stripe_card_charge
    expect(charge).to be_present
    expect(charge.raw_stripe_transactions).to contain_exactly(rst)
  end

  it "skips records that already have a charge" do
    rpst = create(:raw_pending_stripe_transaction)
    rst = create(:raw_stripe_transaction, stripe_authorization_id: nil)

    expect(Maintenance::BackfillPendingStripeCardChargesTask.new.collection).not_to include(rpst)
    expect(Maintenance::BackfillSettledStripeCardChargesTask.new.collection).not_to include(rst)
  end
end
