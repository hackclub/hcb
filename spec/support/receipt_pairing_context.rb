# frozen_string_literal: true

RSpec.shared_context "receipt pairing" do
  let(:user) { create(:user) }
  let(:event) { create(:event, plan_type: Event::Plan::Standard) }
  let(:stripe_card) { create(:stripe_card, :with_stripe_id, stripe_cardholder: create(:stripe_cardholder, user:), event:) }
  let(:charged_at) { Time.zone.parse("2026-10-01 12:00") }

  # A pending card authorization on the user's card.
  def create_charge(amount_cents: 12_34, at: charged_at, merchant: { "name" => "BLUE BOTTLE COFFEE", "postal_code" => "94103" })
    raw_pending_stripe_transaction = create(:raw_pending_stripe_transaction, amount_cents: -amount_cents, date_posted: at.to_date, created_at: at, stripe_transaction: {
                                              "card"              => { "id" => stripe_card.stripe_id },
                                              "approved"          => true,
                                              "merchant_data"     => merchant,
                                              "merchant_amount"   => amount_cents,
                                              "merchant_currency" => "usd"
                                            })
    cpt = create(:canonical_pending_transaction, raw_pending_stripe_transaction:, amount_cents: -amount_cents, date: at.to_date, created_at: at)
    create(:canonical_pending_event_mapping, canonical_pending_transaction: cpt, event:)
    cpt.local_hcb_code.tap { |hcb_code| hcb_code.update_columns(created_at: at) }
  end

  def create_receipt(receiptable: nil, **extracted)
    Receipt.new(user:, receiptable:, upload_method: :api, data_extracted: true, created_at: charged_at, **extracted).tap do |receipt|
      receipt.file.attach(
        io: StringIO.new(File.binread(Rails.root.join("spec/fixtures/files/receipt.png"))),
        filename: "receipt.png", content_type: "image/png"
      )
      receipt.save!
    end
  end
end
