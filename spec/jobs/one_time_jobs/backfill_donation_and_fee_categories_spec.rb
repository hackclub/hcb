# frozen_string_literal: true

require "rails_helper"

RSpec.describe OneTimeJobs::BackfillDonationAndFeeCategories do
  it "assigns the appropriate category" do
    invoice = create(:invoice)
    invoice_cpt = create(
      :canonical_pending_transaction,
      raw_pending_invoice_transaction: create(
        :raw_pending_invoice_transaction,
        invoice_transaction_id: invoice.id.to_s,
      )
    )

    donation = create(:donation)
    donation_cpt = create(
      :canonical_pending_transaction,
      raw_pending_donation_transaction: create(
        :raw_pending_donation_transaction,
        donation_transaction_id: donation.id.to_s
      )
    )

    bank_fee = create(:bank_fee)
    bank_fee_cpt = create(
      :canonical_pending_transaction,
      raw_pending_bank_fee_transaction: create(
        :raw_pending_bank_fee_transaction,
        bank_fee_transaction_id: bank_fee.id.to_s,
      )
    )

    # `StripeServiceFee` creates a `StripeTopup` on creation, which results in a
    # call to the Stripe API
    stub_request(:post, "https://api.stripe.com/v1/topups")
      .to_return(status: 200, body: { id: "tu_1" }.to_json, headers: {})
    stripe_service_fee = StripeServiceFee.create!(
      amount_cents: 12_34,
      stripe_balance_transaction_id: "txn_1",
      stripe_description: "Test description"
    )
    local_hcb_code = stripe_service_fee.local_hcb_code
    stripe_ct = create(:canonical_transaction)
    stripe_ct.update!(hcb_code: local_hcb_code.hcb_code)

    # Copied over from `FeeReimbursementService::Nightly`
    fee_reimbursement_hcb_code = [
      TransactionGroupingEngine::Calculate::HcbCode::HCB_CODE,
      TransactionGroupingEngine::Calculate::HcbCode::OUTGOING_FEE_REIMBURSEMENT_CODE,
      Time.now.strftime("%G_%V")
    ].join(TransactionGroupingEngine::Calculate::HcbCode::SEPARATOR)
    HcbCode.create!(hcb_code: fee_reimbursement_hcb_code)
    fee_reimbursement_ct = create(:canonical_transaction)
    fee_reimbursement_ct.update!(hcb_code: fee_reimbursement_hcb_code)

    fee_revenue = FeeRevenue.create!(
      amount_cents: 12_34,
      start: Date.current.beginning_of_month,
      end: Date.current.end_of_month,
    )
    fee_revenue_local_hcb_code = fee_revenue.local_hcb_code
    fee_revenue_ct = create(:canonical_transaction, memo: "HCB-#{fee_revenue_local_hcb_code.short_code}")

    Sidekiq::Testing.inline! do
      described_class.perform_async
    end

    expect(invoice_cpt.reload.category.slug).to eq("donations")
    expect(donation_cpt.reload.category.slug).to eq("donations")
    expect(bank_fee_cpt.reload.category.slug).to eq("fiscal-sponsorship-fees")
    expect(stripe_ct.reload.category.slug).to eq("stripe-service-fees")
    expect(fee_reimbursement_ct.reload.category.slug).to eq("stripe-fee-reimbursements")
    expect(fee_revenue_ct.reload.category.slug).to eq("hcb-revenue")
  end
end
