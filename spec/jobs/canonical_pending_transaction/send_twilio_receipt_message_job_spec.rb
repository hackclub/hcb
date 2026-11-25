# frozen_string_literal: true

require "rails_helper"

RSpec.describe CanonicalPendingTransaction::SendTwilioReceiptMessageJob do
  # `phone_number_verified` is reset whenever `phone_number` changes, so set it separately.
  let(:user) { create(:user, phone_number: "+18556254225").tap { |u| u.update!(phone_number_verified: true) } }
  let(:cpt) { create(:canonical_pending_transaction, amount_cents: -12_34, memo: "Bakery") }
  let(:sender) { instance_double(TwilioMessageService::Send, run!: true) }

  before { allow(TwilioMessageService::Send).to receive(:new).and_return(sender) }

  it "texts about the charge and records its transaction" do
    cpt.ledger_item.update_columns(receipt_required: true)

    described_class.perform_now(cpt_id: cpt.id, user_id: user.id)

    expect(TwilioMessageService::Send).to have_received(:new).with(
      user,
      a_string_matching(/charged \$12\.34 at 'Bakery'.*attach a receipt/),
      ledger_item: cpt.ledger_item
    )
  end

  it "doesn't ask for a receipt when none is required" do
    cpt.ledger_item.update_columns(receipt_required: false)

    described_class.perform_now(cpt_id: cpt.id, user_id: user.id)

    expect(TwilioMessageService::Send).to have_received(:new).with(user, "Your card was charged $12.34 at 'Bakery'.", ledger_item: cpt.ledger_item)
  end

  it "doesn't text an unverified number" do
    user.update!(phone_number_verified: false)

    described_class.perform_now(cpt_id: cpt.id, user_id: user.id)

    expect(TwilioMessageService::Send).not_to have_received(:new)
  end
end
