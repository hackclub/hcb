# frozen_string_literal: true

require "rails_helper"

RSpec.describe PersonalTransaction, type: :model do
  include_context "card locking charges"

  let(:now) { Time.zone.parse("2026-10-10 12:00:00") }

  before { travel_to(now) }

  describe "after_create" do
    it "marks the underlying hcb_code's receipt no/lost via ledger_item, materializing card-locking state" do
      hc = create_settled_card_charge(user:, settled_at: 12.days.ago)
      hc.update!(card_charge_settled_at: 12.days.ago, receipt_due_at: 12.days.ago + 7.days)
      card_charge = CardCharge.create!(stripe_card: hc.stripe_card)
      hc.ledger_item.update!(linked_object: card_charge)
      # invoice passed explicitly (as the backfill task does) so send_invoice
      # never runs and this doesn't touch InvoiceService::Create/Stripe.
      expect_any_instance_of(Sponsor).to receive(:create_stripe_customer).and_return(true)
      invoice = create(:invoice)

      PersonalTransaction.create!(ledger_item: hc.ledger_item, reporter: user, invoice:)

      expect(hc.reload.marked_no_or_lost_receipt_at).to be_within(1.second).of(now)
      expect(hc.receipt_resolved_at).to be_within(1.second).of(now)
      expect(hc.ledger_item.reload.marked_no_or_lost_receipt_at).to be_within(1.second).of(now)
    end
  end
end
