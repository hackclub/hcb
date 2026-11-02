# frozen_string_literal: true

require "rails_helper"

RSpec.describe CanonicalPendingTransaction::SendTwilioReceiptMessageJob do
  include HcbCodeHelper

  let(:user) { create(:user, phone_number: "+18556254225") }
  let(:event) { create(:event) }
  let(:cpt) { create(:canonical_pending_transaction, event:, amount_cents: -1_00, memo: "Coffee") }
  let(:hcb_code) { cpt.local_hcb_code }

  before do
    user.update_column(:phone_number_verified, true)
    allow(hcb_code).to receive(:receipt_required?).and_return(true)
    allow(CanonicalPendingTransaction).to receive(:find).with(cpt.id).and_return(cpt)
    allow(TwilioMessageService::Send).to receive(:new).and_return(
      instance_double(TwilioMessageService::Send, run!: nil)
    )
  end

  def body_for_sms
    described_class.perform_now(cpt_id: cpt.id, user_id: user.id)

    args = nil
    expect(TwilioMessageService::Send).to have_received(:new) { |*call_args, **| args = call_args }
    args[1]
  end

  it "texts the short receipt link" do
    expect(body_for_sms).to start_with("Your card was charged")
      .and match(/#{Regexp.escape(Rails.application.routes.url_helpers.root_url)}r\/#{hcb_code.hashid}\//)
  end

  it "does not text the long signed receipt url" do
    expect(body_for_sms).not_to include(attach_receipt_url(hcb_code))
  end
end
