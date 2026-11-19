# frozen_string_literal: true

require "rails_helper"

RSpec.describe CanonicalPendingTransaction::SendTwilioReceiptMessageJob do
  # `phone_number_verified` is reset whenever `phone_number` changes, so set it separately.
  let(:user) { create(:user, phone_number: "+18556254225").tap { |u| u.update!(phone_number_verified: true) } }
  let(:cpt) { create(:canonical_pending_transaction, amount_cents: -12_34, memo: "Bakery") }
  let(:sender) { instance_double(TwilioMessageService::Send, run!: true) }

  before { allow(TwilioMessageService::Send).to receive(:new).and_return(sender) }

  it "texts about the charge and records its transaction" do
    allow_any_instance_of(HcbCode).to receive(:receipt_required?).and_return(true)

    described_class.perform_now(cpt_id: cpt.id, user_id: user.id)

    expect(TwilioMessageService::Send).to have_received(:new).with(
      user,
      a_string_matching(/charged \$12\.34 at 'Bakery'.*attach a receipt/),
      hcb_code: cpt.local_hcb_code,
      ledger_item: cpt.ledger_item
    )
    expect(cpt.ledger_item).to be_present
  end

  it "doesn't ask for a receipt when none is required" do
    allow_any_instance_of(HcbCode).to receive(:receipt_required?).and_return(false)

    described_class.perform_now(cpt_id: cpt.id, user_id: user.id)

    expect(TwilioMessageService::Send).to have_received(:new).with(user, "Your card was charged $12.34 at 'Bakery'.", anything)
  end

  it "doesn't text an unverified number" do
    user.update!(phone_number_verified: false)

    described_class.perform_now(cpt_id: cpt.id, user_id: user.id)

    expect(TwilioMessageService::Send).not_to have_received(:new)
  end
end
