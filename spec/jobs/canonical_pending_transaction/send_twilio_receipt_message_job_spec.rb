# frozen_string_literal: true

require "rails_helper"

RSpec.describe CanonicalPendingTransaction::SendTwilioReceiptMessageJob do
  include HcbCodeHelper

  # `phone_number_verified` is reset whenever `phone_number` changes, so set it separately.
  let(:user) { create(:user, phone_number: "+18556254225").tap { |u| u.update!(phone_number_verified: true) } }
  let(:cpt) { create(:canonical_pending_transaction, amount_cents: -12_34, memo: "Bakery") }
  let(:hcb_code) { cpt.local_hcb_code }
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

  context "when a receipt is required" do
    let!(:body) do
      cpt.ledger_item.update_columns(receipt_required: true)
      described_class.perform_now(cpt_id: cpt.id, user_id: user.id)

      captured = nil
      expect(TwilioMessageService::Send).to have_received(:new) { |*, body, **| captured = body }
      captured
    end

    it "texts the short receipt link" do
      expect(body).to match(/#{Regexp.escape(Rails.application.routes.url_helpers.root_url)}r\/#{hcb_code.hashid}\//)
    end

    it "does not text the long signed receipt url" do
      expect(body).not_to include(attach_receipt_url(hcb_code))
    end
  end
end
