# frozen_string_literal: true

require "rails_helper"

RSpec.describe CanonicalPendingTransaction::SendTwilioDeclinedMessageJob do
  # `phone_number_verified` is reset whenever `phone_number` changes, so set it separately.
  let(:user) { create(:user, phone_number: "+18556254225").tap { |u| u.update!(phone_number_verified: true) } }
  let(:stripe_card) { create(:stripe_card, :with_stripe_id, stripe_cardholder: create(:stripe_cardholder, user:)) }
  let(:authorization_method) { "chip" }
  let(:raw_pending_stripe_transaction) do
    create(:raw_pending_stripe_transaction, amount_cents: -12_34, stripe_transaction: {
             "card"                 => { "id" => stripe_card.stripe_id },
             "approved"             => false,
             "authorization_method" => authorization_method,
             "merchant_data"        => { "name" => "Bakery" },
             "request_history"      => [{ "approved" => false, "reason" => "suspected_fraud" }]
           })
  end
  let(:cpt) { create(:canonical_pending_transaction, raw_pending_stripe_transaction:, amount_cents: -12_34) }
  let(:sender) { instance_double(TwilioMessageService::Send, run!: true) }

  before { allow(TwilioMessageService::Send).to receive(:new).and_return(sender) }

  it "texts about the decline and records its transaction" do
    described_class.perform_now(cpt_id: cpt.id, user_id: user.id)

    expect(TwilioMessageService::Send).to have_received(:new).with(
      user,
      "Your card was declined just now at Bakery due to suspected fraud.",
      hcb_code: cpt.local_hcb_code,
      ledger_item: cpt.ledger_item
    )
    expect(cpt.ledger_item).to be_present
  end

  context "for an online charge" do
    let(:authorization_method) { "online" }

    it "doesn't text" do
      described_class.perform_now(cpt_id: cpt.id, user_id: user.id)

      expect(TwilioMessageService::Send).not_to have_received(:new)
    end
  end
end
