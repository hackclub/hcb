# frozen_string_literal: true

require "rails_helper"

RSpec.describe CanonicalPendingTransaction::SendTwilioReceiptMessageJob do
  let(:user) { create(:user, phone_number: "+18556254225").tap { |u| u.update!(phone_number_verified: true) } }
  let(:cpt) { create(:canonical_pending_transaction, amount_cents: -1234) }

  before { allow_any_instance_of(HcbCode).to receive(:receipt_required?).and_return(true) }

  it "states the same reply window the webhook enforces" do
    expect(OutgoingTwilioMessage::RECEIPT_REPLY_WINDOW).to eq(10.minutes)
    expect(TwilioMessageService::Send).to receive(:new)
      .with(user, a_string_including("text us an image within ten minutes,"), hcb_code: cpt.local_hcb_code)
      .and_return(instance_double(TwilioMessageService::Send, run!: true))

    described_class.perform_now(cpt_id: cpt.id, user_id: user.id)
  end
end
