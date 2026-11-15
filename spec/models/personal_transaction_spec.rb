# frozen_string_literal: true

require "rails_helper"

RSpec.describe PersonalTransaction, type: :model do
  include_context "card locking charges"

  let(:now) { Time.zone.parse("2026-10-10 12:00:00") }

  before { travel_to(now) }

  describe "after_create" do
    it "marks the ledger item's receipt no/lost, materializing card-locking state and syncing the HCB code" do
      charge = create_settled_card_charge(user:, settled_at: 12.days.ago)
      charge.update!(receipt_due_at: 12.days.ago + 7.days)
      # invoice passed explicitly (as the backfill task does) so send_invoice
      # never runs and this doesn't touch InvoiceService::Create/Stripe.
      expect_any_instance_of(Sponsor).to receive(:create_stripe_customer).and_return(true)
      invoice = create(:invoice)

      PersonalTransaction.create!(ledger_item: charge, reporter: user, invoice:)

      expect(charge.reload.marked_no_or_lost_receipt_at).to be_within(1.second).of(now)
      expect(charge.receipt_resolved_at).to be_within(1.second).of(now)
      expect(charge.hcb_code.reload.marked_no_or_lost_receipt_at).to be_within(1.second).of(now)
    end
  end
end
