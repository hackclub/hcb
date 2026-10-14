# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscription, type: :model do
  describe "cadence" do
    it "fills cadence_days from the cadence bucket" do
      expect(create(:subscription, cadence: :weekly).cadence_days).to eq(7)
      expect(create(:subscription, cadence: :quarterly).cadence_days).to eq(90)
    end

    it "keeps cadence_days for a custom cadence" do
      subscription = create(:subscription, cadence: :custom, cadence_days: 45)

      expect(subscription.cadence_days).to eq(45)
      expect(subscription.cadence_label).to eq("every 45 days")
    end

    it "requires positive cadence days for a custom cadence" do
      expect(build(:subscription, cadence: :custom, cadence_days: 0)).not_to be_valid
    end
  end

  it "defaults the name to the merchant name" do
    expect(create(:subscription, name: nil, merchant_name: "Vercel").name).to eq("Vercel")
  end

  it "doesn't allow a duplicate active subscription for the same card, merchant and amount" do
    existing = create(:subscription)

    expect(build(:subscription, stripe_card: existing.stripe_card)).not_to be_valid
    expect(build(:subscription, stripe_card: existing.stripe_card, amount_cents: 5_00)).to be_valid

    existing.cancel!
    expect(build(:subscription, stripe_card: existing.stripe_card)).to be_valid
  end

  describe "#matches?" do
    let(:subscription) { create(:subscription, last_charged_at: 30.days.ago) }

    def matches(**overrides)
      subscription.matches?(**{ merchant_network_id: "spotify-123", merchant_name: "SPOTIFY USA", amount_cents: -11_99, at: Time.current }.merge(overrides))
    end

    it "matches on network id, exact amount and timing" do
      expect(matches).to be(true)
    end

    it "falls back to a case-insensitive merchant name when a network id is missing" do
      subscription.update!(merchant_network_id: nil)

      expect(matches(merchant_network_id: nil, merchant_name: "spotify")).to be(true)
      expect(matches(merchant_network_id: nil, merchant_name: "Apple")).to be(false)
    end

    it "doesn't match another network id" do
      expect(matches(merchant_network_id: "other")).to be(false)
    end

    it "doesn't match a different amount" do
      expect(matches(amount_cents: -12_99)).to be(false)
    end

    it "doesn't match a charge too soon after the last one" do
      expect(matches(at: 30.days.ago + 10.days)).to be(false)
    end

    it "matches after skipped cycles" do
      expect(matches(at: 30.days.ago + 61.days)).to be(true)
      expect(matches(at: 30.days.ago + 90.days)).to be(true)
      expect(matches(at: 30.days.ago + 150.days)).to be(false)
    end

    it "matches any time when there's no previous charge" do
      subscription.update!(last_charged_at: nil)

      expect(matches(at: 3.days.from_now)).to be(true)
    end

    it "doesn't match once canceled" do
      subscription.cancel!

      expect(matches).to be(false)
    end
  end

  describe "rates" do
    it "computes monthly and yearly amounts" do
      monthly = build(:subscription, amount_cents: 23_98, cadence: :monthly)
      expect(monthly.monthly_cents).to eq(23_98)
      expect(monthly.yearly_cents).to eq(287_76)

      weekly = build(:subscription, amount_cents: 10_00, cadence: :weekly)
      expect(weekly.yearly_cents).to eq(520_00)
      expect(weekly.monthly_cents).to eq(43_33)

      yearly = build(:subscription, amount_cents: 120_00, cadence: :yearly)
      expect(yearly.monthly_cents).to eq(10_00)
    end

    it "computes custom cadence rates from the number of days" do
      subscription = build(:subscription, amount_cents: 36_50, cadence: :custom, cadence_days: 73)

      expect(subscription.yearly_cents).to eq(182_50)
    end

    it "returns nil without an amount" do
      expect(build(:subscription, amount_cents: nil).monthly_cents).to be_nil
    end
  end

  describe "linking charges" do
    include_context "card locking charges"

    let(:stripe_card) { create(:stripe_card, :with_stripe_id, stripe_cardholder: create(:stripe_cardholder, user:), event:) }
    let(:subscription) { create(:subscription, stripe_card:, event:, amount_cents: 10_00) }

    let!(:first) { create_settled_card_charge(user:, stripe_card:, settled_at: 70.days.ago) }
    let!(:second) { create_settled_card_charge(user:, stripe_card:, settled_at: 40.days.ago) }
    let!(:third) { create_settled_card_charge(user:, stripe_card:, settled_at: 10.days.ago) }

    before do
      [first, second, third].each(&:materialize_card_locking!)
    end

    it "keeps the receipt requirement on the first charge and waives it on the rest" do
      expect(second.reload.receipt_due_at).to be_present

      [third, first, second].each { |hcb_code| hcb_code.update!(subscription:) }
      subscription.sync_charges!

      expect(subscription.first_hcb_code).to eq(first)
      expect(subscription.last_charged_at).to be_within(1.second).of(third.datetime)
      expect(subscription.next_expected_at).to be_within(1.second).of(third.datetime + 30.days)

      expect(first.reload.receipt_required?).to be(true)
      expect(second.reload.receipt_required?).to be(false)
      expect(third.reload.receipt_required?).to be(false)
      expect(second.receipt_due_at).to be_nil
      expect(second.ledger_item.reload.receipt_required).to be(false)
      expect(first.ledger_item.reload.receipt_required).to be(true)
    end

    it "excludes waived charges from the receipt scopes" do
      [first, second, third].each { |hcb_code| hcb_code.update!(subscription:) }
      subscription.sync_charges!

      # These factory charges are force captures (HCB-601), which the
      # receipt_required scope behind User#hcb_code_ids_missing_receipt skips.
      expect(stripe_card.local_hcb_codes.missing_receipt.receipt_not_waived.pluck(:id)).to contain_exactly(first.id)
      expect(user.card_locking_outstanding_charges).to contain_exactly(first)
    end

    it "requires receipts again after being deleted, with a deadline at least 72 hours out" do
      [first, second, third].each { |hcb_code| hcb_code.update!(subscription:) }
      subscription.sync_charges!

      freeze_time do
        perform_enqueued_jobs(only: Subscription::ResyncChargesJob) { subscription.destroy! }

        expect(second.reload.subscription_id).to be_nil
        expect(second.receipt_required?).to be(true)
        expect(second.ledger_item.reload.receipt_required).to be(true)
        expect(second.receipt_due_at).to be >= Time.current + CardLocking::DEADLINE_SHORTENING_FLOOR
      end
    end
  end
end
