# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  # Comfortably after CARD_LOCKING_ENFORCEMENT_START_DATE, but close enough that the
  # six-month averaging window still reaches back before it.
  let(:now) { Time.zone.parse("2026-10-10 12:00:00") }
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

  def create_settled_card_charge(user:, settled_at:, uploaded_at: nil, amount_cents: -10_00, stripe_card: nil, charge_event: nil)
    charge_event ||= event
    stripe_cardholder = user.stripe_cardholder || create(:stripe_cardholder, user:)
    stripe_card ||= create(:stripe_card, :with_stripe_id, stripe_cardholder:, event: charge_event)
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
    create(:canonical_event_mapping, canonical_transaction:, event: charge_event)

    hcb_code = canonical_transaction.local_hcb_code.reload

    if uploaded_at.present?
      attach_receipt(hcb_code, uploaded_by: user)
      hcb_code.receipts.order(:id).last.update_columns(created_at: uploaded_at, updated_at: uploaded_at)
      hcb_code.reload
    end

    hcb_code
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

  describe "#average_receipt_upload_time" do
    it "uses settled charges and clamps uploads that happened before settlement" do
      create_settled_card_charge(user:, settled_at: 7.days.ago, uploaded_at: 6.days.ago)
      create_settled_card_charge(user:, settled_at: 5.days.ago, uploaded_at: 6.days.ago)
      create_settled_card_charge(user:, settled_at: 4.days.ago)

      reloaded_user = described_class.find(user.id)

      expect(reloaded_user.average_receipt_upload_time).to be_within(1.second).of(5.days / 3.0)
    end

    it "excludes missing receipts that are still within the grace period" do
      settled_at = 10.days.ago
      create_settled_card_charge(user:, settled_at:, uploaded_at: settled_at + 24.hours)
      create_settled_card_charge(user:, settled_at: 1.hour.ago)

      expect(described_class.find(user.id).average_receipt_upload_time).to be_within(1.second).of(24.hours)
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

  describe "#card_locking_receipts_past_warning_threshold" do
    def past_threshold(age)
      create_settled_card_charge(user:, settled_at: now - age)

      described_class.find(user.id).card_locking_receipts_past_warning_threshold(threshold: 48.hours)
    end

    it "includes a receipt that has just crossed the threshold" do
      expect(past_threshold(48.hours)).to be_present
    end

    # A skipped or slow run must not be able to drop the warning permanently.
    it "still includes a receipt hours after it crossed the threshold" do
      expect(past_threshold(60.hours)).to be_present
    end

    it "excludes a receipt that has not yet reached the threshold" do
      expect(past_threshold(48.hours - 1.minute)).to be_empty
    end

    # Past the grace period the receipt is a violation, and the digest covers it.
    it "excludes a receipt that is already a violation" do
      expect(past_threshold(User::CARD_LOCKING_RECEIPT_GRACE_PERIOD + 1.minute)).to be_empty
    end
  end

  describe ".card_locking_candidates" do
    def candidate_ids = described_class.card_locking_candidates.pluck(:id)

    it "includes a user with a settled charge that is missing a receipt" do
      create_settled_card_charge(user:, settled_at: 1.hour.ago)

      expect(candidate_ids).to include(user.id)
    end

    it "includes a locked user with no missing receipts, so they can be unlocked" do
      user.update!(cards_locked: true)

      expect(candidate_ids).to include(user.id)
    end

    it "excludes an unlocked user whose receipts are all uploaded" do
      settled_at = 4.days.ago
      create_settled_card_charge(user:, settled_at:, uploaded_at: settled_at + 1.hour)

      expect(candidate_ids).not_to include(user.id)
    end

    it "excludes a user whose only missing receipt is on a SalaryAccount-plan event" do
      create_settled_card_charge(user:, settled_at: 4.days.ago, charge_event: create(:event, plan_type: Event::Plan::SalaryAccount))

      expect(candidate_ids).not_to include(user.id)
    end
  end

  describe "the enforcement start date" do
    let(:before_enforcement) { Receipt::CARD_LOCKING_ENFORCEMENT_START_DATE.beginning_of_day - 5.days }

    it "never counts a charge that settled beforehand against the user" do
      create_settled_card_charge(user:, settled_at: before_enforcement)

      reloaded_user = described_class.find(user.id)

      expect(reloaded_user.card_locking_history_hcb_codes.count).to eq(1) # the charge exists, and is in the window
      expect(reloaded_user.card_locking_missing_receipts).to be_empty
      expect(reloaded_user).not_to be_cards_should_lock
      expect(described_class.card_locking_candidates.pluck(:id)).not_to include(user.id)
    end

    it "still credits receipts the user uploaded beforehand" do
      5.times do |index|
        settled_at = before_enforcement - index.days
        create_settled_card_charge(user:, settled_at:, uploaded_at: settled_at + 1.day)
      end

      expect(described_class.find(user.id).timely_receipt_upload_count).to eq(5)
    end

    # The asymmetry: history earned before enforcement buys flexibility, so a
    # trustworthy cardholder is not treated as unproven on day one.
    it "lets a user proven before enforcement absorb a violation after it" do
      5.times do |index|
        settled_at = before_enforcement - index.days
        create_settled_card_charge(user:, settled_at:, uploaded_at: settled_at + 1.day)
      end
      create_settled_card_charge(user:, settled_at: 4.days.ago)

      expect(described_class.find(user.id)).not_to be_cards_should_lock
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
      create_settled_card_charge(user:, settled_at: 4.days.ago, charge_event: create(:event, plan_type: Event::Plan::SalaryAccount))

      reloaded_user = described_class.find(user.id)

      expect(reloaded_user.card_locking_missing_receipts).to be_empty
      expect(reloaded_user).not_to be_cards_should_lock
    end

    it "does not count charges on events whose plan is no longer active" do
      inactive_event = create(:event, plan_type: Event::Plan::Standard)
      create_settled_card_charge(user:, settled_at: 4.days.ago, charge_event: inactive_event)
      inactive_event.plan.update_columns(aasm_state: "inactive")

      reloaded_user = described_class.find(user.id)

      expect(reloaded_user.card_locking_missing_receipts).to be_empty
      expect(reloaded_user).not_to be_cards_should_lock
    end

    # `cards_should_lock?` reaches through `HcbCode#missing_receipt?` and
    # `#receipt_required?`, which read `event`, `event.plan`, `pt` and `amount_cents`.
    # Without CARD_LOCKING_PRELOADS each of those costs a query per HCB code, for
    # every user with a missing receipt, every time the recurring job runs.
    it "decides in a constant number of queries as a user's history grows" do
      stripe_card = create(:stripe_card, :with_stripe_id, stripe_cardholder: create(:stripe_cardholder, user:), event:)

      build_history = lambda do |uploaded_charge_count, offset|
        uploaded_charge_count.times do |index|
          settled_at = (offset + index).days.ago
          create_settled_card_charge(user:, settled_at:, uploaded_at: settled_at + 1.day, stripe_card:)
        end
        create_settled_card_charge(user:, settled_at: 4.days.ago, stripe_card:) # a violation, so the average is reached
      end

      build_history.call(5, 20)
      small_history = queries_to_decide_locking

      build_history.call(20, 30)
      large_history = queries_to_decide_locking

      expect(large_history).to eq(small_history)
    end
  end
end
