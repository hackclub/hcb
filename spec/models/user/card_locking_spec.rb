# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  let(:now) { Time.zone.parse("2026-05-10 12:00:00") }
  let(:user) { create(:user) }
  let(:event) { create(:event, plan_type: Event::Plan::Standard) }

  around do |example|
    travel_to(now) { example.run }
  end

  def attach_receipt(hcb_code, uploaded_by:)
    receipt = Receipt.new(receiptable: hcb_code, user: uploaded_by, upload_method: :api)
    receipt.file.attach(
      io: StringIO.new(File.binread(Rails.root.join("spec/fixtures/files/receipt.png"))),
      filename: "receipt.png",
      content_type: "image/png"
    )

    receipt.save!
  end

  def create_settled_card_charge(user:, settled_at:, uploaded_at: nil, amount_cents: -10_00, stripe_card: nil)
    stripe_cardholder = user.stripe_cardholder || create(:stripe_cardholder, user:)
    stripe_card ||= create(:stripe_card, :with_stripe_id, stripe_cardholder:, event:)
    raw_stripe_transaction = create(
      :raw_stripe_transaction,
      stripe_card:,
      stripe_authorization_id: SecureRandom.hex(8),
      created_at: settled_at,
      updated_at: settled_at,
      date_posted: settled_at.to_date
    )
    canonical_transaction = create(
      :canonical_transaction,
      amount_cents:,
      memo: "Test Merchant",
      date: settled_at.to_date,
      created_at: settled_at,
      updated_at: settled_at,
      transaction_source: raw_stripe_transaction
    )
    create(:canonical_event_mapping, canonical_transaction:, event:)

    hcb_code = canonical_transaction.local_hcb_code.reload

    if uploaded_at.present?
      attach_receipt(hcb_code, uploaded_by: user)
      hcb_code.receipts.order(:id).last.update_columns(created_at: uploaded_at, updated_at: uploaded_at)
      hcb_code.reload
    end

    hcb_code
  end

  describe "#average_receipt_upload_time" do
    it "uses settled charges and clamps uploads that happened before settlement" do
      create_settled_card_charge(user:, settled_at: 7.days.ago, uploaded_at: 6.days.ago)
      create_settled_card_charge(user:, settled_at: 5.days.ago, uploaded_at: 6.days.ago)
      create_settled_card_charge(user:, settled_at: 4.days.ago)

      reloaded_user = described_class.find(user.id)

      expect(reloaded_user.average_receipt_upload_time).to be_within(1.second).of(5.days / 3.0)
    end

    it "ignores pending charges" do
      stripe_cardholder = user.stripe_cardholder || create(:stripe_cardholder, user:)
      stripe_card = create(:stripe_card, :with_stripe_id, stripe_cardholder:, event:)
      raw_pending_stripe_transaction = create(
        :raw_pending_stripe_transaction,
        stripe_transaction_id: "iauth_pending",
        created_at: 8.days.ago,
        updated_at: 8.days.ago,
        stripe_transaction: {
          "id"                   => "iauth_pending",
          "card"                 => { "id" => stripe_card.stripe_id },
          "authorization_method" => "online",
          "merchant_data"        => { "name" => "Pending Merchant", "category" => "bakeries" }
        }
      )
      canonical_pending_transaction = create(
        :canonical_pending_transaction,
        amount_cents: -10_00,
        memo: "Pending Merchant",
        date: 8.days.ago.to_date,
        created_at: 8.days.ago,
        updated_at: 8.days.ago,
        raw_pending_stripe_transaction:
      )
      create(:canonical_pending_event_mapping, canonical_pending_transaction:, event:)

      reloaded_user = described_class.find(user.id)

      expect(reloaded_user.card_locking_missing_receipts).to be_empty
      expect(reloaded_user.average_receipt_upload_time).to eq(0.seconds)
    end
  end

  describe "#card_locking_missing_receipt_violations" do
    it "does not treat a receipt missing for exactly the grace period as a violation" do
      create_settled_card_charge(user:, settled_at: now - User::CARD_LOCKING_RECEIPT_GRACE_PERIOD)

      expect(described_class.find(user.id).card_locking_missing_receipt_violations).to be_empty
    end

    it "treats a receipt missing for longer than the grace period as a violation" do
      create_settled_card_charge(user:, settled_at: now - User::CARD_LOCKING_RECEIPT_GRACE_PERIOD - 1.second)

      expect(described_class.find(user.id).card_locking_missing_receipt_violations.count).to eq(1)
    end
  end

  describe "#timely_receipt_upload_count" do
    it "counts a receipt uploaded at exactly the grace period as timely" do
      settled_at = 10.days.ago
      create_settled_card_charge(user:, settled_at:, uploaded_at: settled_at + User::CARD_LOCKING_RECEIPT_GRACE_PERIOD)

      expect(described_class.find(user.id).timely_receipt_upload_count).to eq(1)
    end

    it "does not count a receipt uploaded after the grace period as timely" do
      settled_at = 10.days.ago
      create_settled_card_charge(user:, settled_at:, uploaded_at: settled_at + User::CARD_LOCKING_RECEIPT_GRACE_PERIOD + 1.second)

      expect(described_class.find(user.id).timely_receipt_upload_count).to eq(0)
    end
  end

  describe "#cards_should_lock?" do
    it "locks new users with fewer than five timely uploads once they have a violation" do
      4.times do |index|
        settled_at = (20 + index).days.ago
        create_settled_card_charge(user:, settled_at:, uploaded_at: settled_at + 1.day)
      end

      create_settled_card_charge(user:, settled_at: 4.days.ago)

      expect(described_class.find(user.id)).to be_cards_should_lock
    end

    it "keeps trustworthy users unlocked when their recent average stays below 72 hours" do
      5.times do |index|
        settled_at = (25 + index).days.ago
        create_settled_card_charge(user:, settled_at:, uploaded_at: settled_at + 1.day)
      end

      create_settled_card_charge(user:, settled_at: 4.days.ago)

      expect(described_class.find(user.id)).not_to be_cards_should_lock
    end

    it "locks when a receipt has been missing for more than a week" do
      5.times do |index|
        settled_at = (30 + index).days.ago
        create_settled_card_charge(user:, settled_at:, uploaded_at: settled_at + 1.day)
      end

      create_settled_card_charge(user:, settled_at: 8.days.ago)

      expect(described_class.find(user.id)).to be_cards_should_lock
    end

    it "locks when missing receipt violations reach the hard threshold" do
      5.times do |index|
        settled_at = (30 + index).days.ago
        create_settled_card_charge(user:, settled_at:, uploaded_at: settled_at + 1.day)
      end

      User::CARD_LOCKING_MISSING_RECEIPT_VIOLATION_LOCK_THRESHOLD.times do |index|
        create_settled_card_charge(user:, settled_at: (4.days + index.minutes).ago)
      end

      expect(described_class.find(user.id)).to be_cards_should_lock
    end

    it "locks when total missing receipts reach the hard threshold even without any violations" do
      5.times do |index|
        settled_at = (30 + index).days.ago
        create_settled_card_charge(user:, settled_at:, uploaded_at: settled_at + 1.day)
      end

      stripe_card = create(:stripe_card, :with_stripe_id, stripe_cardholder: user.stripe_cardholder, event:)

      User::CARD_LOCKING_MISSING_RECEIPT_LOCK_THRESHOLD.times do |index|
        create_settled_card_charge(user:, settled_at: (1.hour + index.minutes).ago, stripe_card:)
      end

      expect(described_class.find(user.id)).to be_cards_should_lock
    end

    it "locks when the average upload time exceeds 72 hours despite having enough timely uploads" do
      # 5 timely uploads right at the edge (71h each) — count qualifies but drags average up
      5.times do |index|
        settled_at = (30 + index).days.ago
        create_settled_card_charge(user:, settled_at:, uploaded_at: settled_at + 71.hours)
      end

      # One large violation (5 days missing) pushes the average above 72h
      # avg = (71h * 5 + 5days) / 6 = (355h + 120h) / 6 = 475h / 6 ≈ 79h > 72h
      create_settled_card_charge(user:, settled_at: 5.days.ago)

      expect(described_class.find(user.id)).to be_cards_should_lock
    end

    it "does not count charges on SalaryAccount-plan events toward card locking" do
      salary_event = create(:event, plan_type: Event::Plan::SalaryAccount)

      # Build a charge against the salary event — should be invisible to card locking
      stripe_cardholder = user.stripe_cardholder || create(:stripe_cardholder, user:)
      salary_card = create(:stripe_card, :with_stripe_id, stripe_cardholder:, event: salary_event)
      settled_at = 4.days.ago
      raw = create(:raw_stripe_transaction, stripe_card: salary_card, stripe_authorization_id: SecureRandom.hex(8), created_at: settled_at, updated_at: settled_at, date_posted: settled_at.to_date)
      ct = create(:canonical_transaction, amount_cents: -10_00, memo: "Salary Charge", date: settled_at.to_date, created_at: settled_at, updated_at: settled_at, transaction_source: raw)
      create(:canonical_event_mapping, canonical_transaction: ct, event: salary_event)

      reloaded_user = described_class.find(user.id)

      expect(reloaded_user.card_locking_missing_receipts).to be_empty
      expect(reloaded_user).not_to be_cards_should_lock
    end
  end
end
