# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaypalTransfersController do
  include SessionSupport

  let(:paypal_transfer) do
    # New PayPal transfers are refused at validation, so save past it to stand
    # in for one created before that.
    PaypalTransfer.new(
      event: create(:event, :with_positive_balance),
      user: create(:user),
      amount_cents: 25_00,
      memo: "Stickers",
      payment_for: "Stickers",
      recipient_name: "Orpheus",
      recipient_email: "orpheus@example.com"
    ).tap { |transfer| transfer.save!(validate: false) }
  end

  context "as a non-admin auditor" do
    before { create_session(create(:user, :make_auditor), verified: true) }

    it "refuses to approve a transfer" do
      post(:approve, params: { id: paypal_transfer.id })

      expect(response).to redirect_to(paypal_transfer_process_admin_path(paypal_transfer))
      expect(flash[:error]).to include("approve?")
      expect(paypal_transfer.reload).to be_pending
    end

    it "refuses to reject a transfer" do
      post(:reject, params: { id: paypal_transfer.id, comment: "Nope" })

      expect(flash[:error]).to eq("You are not authorized to perform this action.")
      expect(paypal_transfer.reload).to be_pending
      expect(paypal_transfer.local_hcb_code.comments).to be_empty
    end

    it "refuses to mark a transfer as failed" do
      post(:mark_failed, params: { id: paypal_transfer.id })

      expect(flash[:error]).to eq("You are not authorized to perform this action.")
      expect(paypal_transfer.reload).to be_pending
    end
  end
end
