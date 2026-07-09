# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  let(:now) { Time.zone.parse("2026-05-10 12:00:00") }
  let(:user) { create(:user) }
  let(:event) { create(:event, plan_type: Event::Plan::Standard) }
  let(:stripe_card) { create(:stripe_card, :with_stripe_id, stripe_cardholder: create(:stripe_cardholder, user:), event:) }

  around do |example|
    travel_to(now) { example.run }
  end

  def create_settled_card_charge(settled_at:, uploaded_at: nil)
    raw_stripe_transaction = create(:raw_stripe_transaction, stripe_card:, stripe_authorization_id: SecureRandom.hex(8), created_at: settled_at, updated_at: settled_at, date_posted: settled_at.to_date)
    canonical_transaction = create(:canonical_transaction, amount_cents: -10_00, memo: "Test Merchant", date: settled_at.to_date, created_at: settled_at, updated_at: settled_at, transaction_source: raw_stripe_transaction)
    create(:canonical_event_mapping, canonical_transaction:, event:)

    hcb_code = canonical_transaction.local_hcb_code.reload
    return hcb_code if uploaded_at.blank?

    receipt = Receipt.new(receiptable: hcb_code, user:, upload_method: :api)
    receipt.file.attach(io: StringIO.new(File.binread(Rails.root.join("spec/fixtures/files/receipt.png"))), filename: "receipt.png", content_type: "image/png")
    receipt.save!
    hcb_code.receipts.order(:id).last.update_columns(created_at: uploaded_at, updated_at: uploaded_at)

    hcb_code.reload
  end

  def queries_to_decide_locking
    count = 0
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      count += 1 unless payload[:name] == "SCHEMA"
    end
    described_class.find(user.id).cards_should_lock?
    count
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription)
  end

  # `cards_should_lock?` reaches through `HcbCode#missing_receipt?` and
  # `#receipt_required?`, which read `event`, `event.plan`, `pt` and `amount_cents`.
  # Each of those used to cost a query per HCB code, on a five minute cron, for
  # every user with a missing receipt.
  it "decides card locking in a constant number of queries as a user's history grows" do
    build_history = lambda do |uploaded_charge_count, offset|
      uploaded_charge_count.times do |index|
        settled_at = (offset + index).days.ago
        create_settled_card_charge(settled_at:, uploaded_at: settled_at + 1.day)
      end
      create_settled_card_charge(settled_at: 4.days.ago) # one violation, so the average is reached
    end

    build_history.call(5, 20)
    small_history = queries_to_decide_locking

    build_history.call(20, 30)
    large_history = queries_to_decide_locking

    expect(large_history).to eq(small_history)
  end
end
