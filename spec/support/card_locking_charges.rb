# frozen_string_literal: true

RSpec.shared_context "card locking charges" do
  let(:user) { create(:user) }
  let(:event) { create(:event, plan_type: Event::Plan::Standard) }

  # Enroll the cardholder in the first rollout stage (enforcement start
  # 2026-07-14) so materialize sets deadlines. Specs exercising pre-enforcement
  # settle charges before that date; specs exercising a non-enrolled cardholder
  # disable this flag.
  before { Flipper.enable(:card_locking_enabled_on_07_17_2026, user) }

  # Attach at the correct time so the resolution callback (added later) freezes
  # against the right timestamp. Do NOT attach-then-backdate.
  def attach_receipt(hcb_code, uploaded_by:, at: nil)
    build_and_save = lambda do
      receipt = Receipt.new(receiptable: hcb_code, user: uploaded_by, upload_method: :api)
      receipt.file.attach(
        io: StringIO.new(File.binread(Rails.root.join("spec/fixtures/files/receipt.png"))),
        filename: "receipt.png", content_type: "image/png"
      )
      receipt.save!
      receipt
    end
    at ? travel_to(at) { build_and_save.call } : build_and_save.call
  end

  def create_settled_card_charge(user:, settled_at:, uploaded_at: nil, amount_cents: -10_00, stripe_card: nil, charge_event: nil)
    charge_event ||= event
    stripe_cardholder = user.stripe_cardholder || create(:stripe_cardholder, user:)
    stripe_card ||= create(:stripe_card, :with_stripe_id, stripe_cardholder:, event: charge_event)
    raw_stripe_transaction = create(
      :raw_stripe_transaction, stripe_card:, stripe_authorization_id: SecureRandom.hex(8),
      created_at: settled_at, updated_at: settled_at, date_posted: settled_at.to_date
    )
    canonical_transaction = create(
      :canonical_transaction, amount_cents:, memo: "Test Merchant", date: settled_at.to_date,
      created_at: settled_at, updated_at: settled_at, transaction_source: raw_stripe_transaction
    )
    create(:canonical_event_mapping, canonical_transaction:, event: charge_event)

    hcb_code = canonical_transaction.local_hcb_code.reload
    attach_receipt(hcb_code, uploaded_by: user, at: uploaded_at) if uploaded_at.present?
    hcb_code.reload
  end
end
