# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscription::Detect do
  include_context "card locking charges"

  before { travel_to(Time.zone.local(2026, 11, 1, 12)) }

  let(:stripe_card) { create(:stripe_card, :with_stripe_id, stripe_cardholder: create(:stripe_cardholder, user:), event:) }
  let(:someone_elses) { create(:stripe_card, :with_stripe_id, stripe_cardholder: create(:stripe_cardholder), event:) }
  let(:start) { 300.days.ago }

  # Settles a charge `day` days after the start and runs detection on it, as
  # the job does. Returns the charge's subscription, if any.
  def charge(day, amount_cents: -20_00, network_id: "vercel-1", card: stripe_card, merchant_category: "bakeries", authorization_method: nil)
    ledger_item = settle(day, amount_cents:, network_id:, card:, merchant_category:)
    authorize(ledger_item, authorization_method) if authorization_method
    described_class.new(ledger_item.reload).run
    ledger_item.reload.subscription
  end

  def settle(day, amount_cents: -20_00, network_id: "vercel-1", card: stripe_card, merchant_category: "bakeries")
    create_settled_card_charge(user:, stripe_card: card, settled_at: start + day.days, amount_cents:, merchant_network_id: network_id, merchant_category:).ledger_item
  end

  # Attaches the authorization the charge settled from.
  def authorize(ledger_item, authorization_method)
    raw_stripe_transaction = ledger_item.linked_object.raw_stripe_transactions.sole
    raw_pending_stripe_transaction = create(:raw_pending_stripe_transaction, stripe_transaction_id: raw_stripe_transaction.stripe_authorization_id, stripe_card: ledger_item.linked_object.stripe_card)
    raw_pending_stripe_transaction.update!(stripe_transaction: raw_pending_stripe_transaction.stripe_transaction.merge("authorization_method" => authorization_method))
  end

  def days_after_start(time)
    ((time - start) / 1.day).round
  end

  it "detects a flat monthly subscription on the third charge" do
    expect(charge(0)).to be_nil
    expect(charge(31)).to be_nil

    expect(charge(61)).to have_attributes(
      cadence_days: 30, cadence_label: "monthly", amount_cents: 20_00, variable_amount: false,
      merchant_key: "vercel-1", ledger: event.ledger, payment_rail: stripe_card,
      last_charged_at: be_within(1.second).of(start + 61.days),
      next_expected_at: be_within(1.second).of(start + 91.days)
    )
    expect(Subscription.sole.ledger_items.count).to eq(3)
  end

  it "detects other cadences, with a skipped cycle" do
    [0, 61, 181].each { |day| charge(day) }

    expect(charge(240)).to have_attributes(cadence_days: 60, cadence_label: "every two months")
  end

  it "expects the next charge a cycle after a chain that skipped one" do
    charge(0)
    charge(30)

    expect(days_after_start(charge(88).next_expected_at)).to eq(118)
  end

  it "needs four charges when they are spread over different cardholders' cards" do
    cards = [stripe_card, someone_elses]

    expect([0, 30, 60].map { |day| charge(day, card: cards[(day / 30) % 2]) }).to all(be_nil)
    expect(charge(90, card: cards[1]).ledger_items.count).to eq(4)
  end

  it "separates two subscriptions at the same price on one card" do
    first = [0, 30, 60].map { |day| charge(day) }.last
    second = [12, 42, 72].map { |day| charge(day) }.last

    expect(first.ledger_items.count).to eq(3)
    expect(second.ledger_items.count).to eq(3)
    expect(second).not_to eq(first)
  end

  it "does not read two alternating prices as one usage-based subscription" do
    charge(0, amount_cents: -10_00)
    charge(15, amount_cents: -25_00)

    expect(charge(30, amount_cents: -10_00)).to be_nil
  end

  it "finds a subscription among one-off purchases at the same price" do
    charge(0)
    charge(37) # too far off to be the previous cycle
    charge(67)
    charge(81) # a one-off
    charge(97)

    expect(charge(127).ledger_items.count).to eq(4)
  end

  it "leaves a one-off purchase out of a flat subscription" do
    charge(0)
    charge(30)

    expect(charge(58, amount_cents: -45_00)).to be_nil
    expect(charge(60)).to have_attributes(variable_amount: false, amount_cents: 20_00)
  end

  it "does not read a flat price with an uneven gap as a varying amount" do
    charge(0)
    charge(34)

    expect(charge(64)).to be_nil
  end

  it "ignores a cycle that isn't a known cadence" do
    [0, 43, 86, 129].each { |day| charge(day) }

    expect(Subscription.count).to eq(0)
  end

  it "detects a yearly subscription from two charges" do
    charge(-100)

    expect(charge(270)).to have_attributes(cadence_days: 365)
  end

  it "detects a yearly subscription next to a one-off at the same price" do
    charge(-100)
    charge(205)

    expect(charge(265)).to have_attributes(cadence_days: 365)
  end

  it "detects usage-based billing as a variable amount" do
    charge(0, amount_cents: -31_40)
    charge(30, amount_cents: -18_05)

    expect(charge(61, amount_cents: -52_90)).to have_attributes(cadence_days: 30, variable_amount: true, amount_cents: 52_90)
    expect(charge(91, amount_cents: -7_00)).to eq(Subscription.sole)
  end

  it "detects usage-based billing once a repeated amount is at most a third of its charges" do
    [[0, -5_00], [30, -12_34], [60, -5_00], [90, -7_10], [120, -9_80]].each do |day, amount_cents|
      expect(charge(day, amount_cents:)).to be_nil
    end

    expect(charge(150, amount_cents: -11_00)).to have_attributes(variable_amount: true, cadence_days: 30)
  end

  it "is more confident in a long, flat, regular subscription than a short, varying one" do
    flat = [0, 30, 60, 90, 120, 150].map { |day| charge(day) }.last
    varying = [0, 27, 62].map { |day| charge(day, amount_cents: -(10_00 + (day * 100)), network_id: "parts-1") }.last

    expect(flat.confidence).to eq(100 - Subscription::WEIGHTS[:category])
    expect(varying.signals).to include(charges: 0.4, amount: be_within(0.01).of(0.33), card: 1.0, no_skips: 1.0)
    expect(varying.confidence).to be < 50
  end

  it "scores merchants that sell subscriptions" do
    subscription = [0, 30, 60].map { |day| charge(day, merchant_category: "direct_marketing_subscription") }.last

    expect(subscription.signals).to include(category: 1.0)
  end

  it "adds up its confidence from the points for each signal" do
    subscription = [0, 27, 62].map { |day| charge(day, amount_cents: -(10_00 + (day * 100))) }.last

    expect(subscription.confidence).to eq(subscription.points.values.sum)
    expect(subscription.points.keys).to eq(Subscription::WEIGHTS.keys)
  end

  it "ignores purchases that aren't on a cadence" do
    [0, 3, 6, 40, 47].each { |day| charge(day, amount_cents: -(5_00 + day)) }
    [0, 3, 6].each { |day| charge(day, network_id: "coffee-1") }

    expect(Subscription.count).to eq(0)
  end

  %w[chip swipe contactless].each do |authorization_method|
    it "ignores #{authorization_method} charges" do
      charge(0, authorization_method:)
      charge(30)

      expect(charge(60)).to be_nil
    end
  end

  it "counts charges authorized online" do
    charge(0, authorization_method: "online")
    charge(30)

    expect(charge(60).ledger_items.count).to eq(3)
  end

  it "ignores charges without a card" do
    settle(0).linked_object.update_column(:stripe_card_id, nil)
    charge(30)

    expect(charge(60)).to be_nil
    expect(charge(90).ledger_items.count).to eq(3)
  end

  context "with a monthly subscription due on day 90" do
    let!(:subscription) { [0, 30, 60].map { |day| charge(day) }.last }

    it "links a late charge and keeps the billing day" do
      expect(charge(101)).to eq(subscription)
      expect(subscription.reload.next_expected_at).to be_within(1.second).of(start + 120.days)
      expect(charge(120)).to eq(subscription)
    end

    it "links a charge most of a cycle late and the on-time charge after it" do
      expect(charge(115)).to eq(subscription)
      expect(charge(120)).to eq(subscription)
    end

    it "links a second late payment and the on-time charge after it" do
      expect(charge(100)).to eq(subscription)
      expect(charge(128)).to eq(subscription)
      expect(charge(150)).to eq(subscription)
    end

    it "moves the billing day to a charge that comes whole cycles after the last one" do
      expect(charge(118)).to eq(subscription)
      expect(days_after_start(subscription.reload.next_expected_at)).to eq(148)
      expect(charge(119)).to be_nil
    end

    it "keeps one subscription when the billing day moves" do
      [80, 110, 140, 170, 200].each { |day| charge(day) }

      expect(Subscription.sole).to eq(subscription)
      expect(subscription.ledger_items.count).to eq(7)
      expect(days_after_start(subscription.reload.next_expected_at)).to eq(230)
    end

    it "leaves out a repeat charge" do
      expect(charge(62)).to be_nil
      expect(charge(90)).to eq(subscription)
    end

    it "leaves out an in-person charge" do
      expect(charge(90, authorization_method: "chip")).to be_nil
      expect(subscription.ledger_items.count).to eq(3)
    end

    it "follows a price change" do
      expect(charge(90, amount_cents: -22_00)).to eq(subscription)
      expect(subscription.reload.amount_cents).to eq(22_00)
    end

    it "follows the subscription to another card" do
      replacement = create(:stripe_card, :with_stripe_id, stripe_cardholder: stripe_card.stripe_cardholder, event:)

      expect(charge(90, card: replacement)).to eq(subscription)
      expect(subscription.reload.payment_rail).to eq(replacement)
    end

    context "with a charge on another cardholder's card" do
      it "leaves it alone while the cardholder's own charge is due" do
        expect(charge(90, card: someone_elses)).to be_nil
        expect(charge(91)).to eq(subscription)
      end

      it "leaves it alone while the cardholder may still pay late" do
        expect(charge(97, card: someone_elses)).to be_nil
        expect(charge(100)).to eq(subscription)
      end

      it "moves the subscription to it once the cardholder has missed a charge" do
        expect(charge(118, card: someone_elses)).to eq(subscription)
        expect(subscription.reload.payment_rail).to eq(someone_elses)
        expect(charge(148, card: someone_elses)).to eq(subscription)
      end

      it "leaves it alone when it is a different amount" do
        expect(charge(118, card: someone_elses, amount_cents: -22_00)).to be_nil
      end

      it "does not bring back a lapsed subscription" do
        expect(charge(290, card: someone_elses)).to be_nil
        expect(subscription.ledger_items.count).to eq(3)
      end

      it "keeps two cardholders' subscriptions at the same price apart" do
        [90, 120, 150, 180].each do |day|
          charge(day, card: someone_elses)
          charge(day + 1)
        end

        expect(subscription.reload.ledger_items.count).to eq(7)
        expect(Subscription.where.not(id: subscription.id).sole).to have_attributes(payment_rail: someone_elses)
      end

      it "prefers a subscription of the charge's own cardholder" do
        theirs = [27, 57, 87].map { |day| charge(day, card: someone_elses) }.last
        replacement = create(:stripe_card, :with_stripe_id, stripe_cardholder: someone_elses.stripe_cardholder, event:)

        expect(charge(117, card: replacement)).to eq(theirs)
      end

      it "gives the subscription back when the charge that moved it leaves" do
        moved = settle(118, card: someone_elses)
        described_class.new(moved).run

        Ledger::Mapping.map_primary!(ledger: create(:event).ledger, ledger_item: moved.reload, mapped_by: create(:user))
        perform_enqueued_jobs(only: Subscription::RecomputeJob)

        expect(subscription.reload.payment_rail).to eq(stripe_card)
      end
    end

    it "keeps a different price at the same merchant separate" do
      other = [63, 93, 123].map { |day| charge(day, amount_cents: -99_00) }.last

      expect(other).to have_attributes(amount_cents: 99_00)
      expect(other).not_to eq(subscription)
      expect(subscription.reload.ledger_items.count).to eq(3)
    end

    it "is lapsed once a whole cycle is missed" do
      travel_to(start + 100.days) { expect(subscription.lapsed?).to be(false) }
      travel_to(start + 121.days) { expect(subscription.lapsed?).to be(true) }
    end

    it "does nothing for a charge that is already linked" do
      expect { described_class.new(subscription.ledger_items.last).run }.not_to(change { subscription.reload.next_expected_at })
    end

    it "lets a charge go when it moves to another organization" do
      moved = subscription.ledger_items.order(:datetime).last

      expect {
        Ledger::Mapping.map_primary!(ledger: create(:event).ledger, ledger_item: moved, mapped_by: create(:user))
      }.to have_enqueued_job(Subscription::DetectJob).with(moved)
      perform_enqueued_jobs(only: Subscription::RecomputeJob)

      expect(moved.reload.subscription).to be_nil
      expect(subscription.reload).to have_attributes(
        last_charged_at: be_within(1.second).of(start + 30.days),
        next_expected_at: be_within(1.second).of(start + 60.days)
      )
      expect(subscription.ledger_items.count).to eq(2)
    end

    it "queues the jobs for a moved charge once the move commits" do
      moved = subscription.ledger_items.order(:datetime).last

      ActiveRecord::Base.transaction do
        Ledger::Mapping.map_primary!(ledger: create(:event).ledger, ledger_item: moved, mapped_by: create(:user))

        expect(Subscription::RecomputeJob).not_to have_been_enqueued
      end

      expect(Subscription::RecomputeJob).to have_been_enqueued.with(subscription.id)
    end

    it "deletes the subscription once every charge has left its ledger" do
      subscription.ledger_items.each do |ledger_item|
        Ledger::Mapping.map_primary!(ledger: nil, ledger_item:, mapped_by: create(:user))
      end
      perform_enqueued_jobs(only: Subscription::RecomputeJob)

      expect(Subscription.count).to eq(0)
    end

    it "recomputes from the charges that still spend money" do
      last, middle = subscription.ledger_items.order(datetime: :desc).first(2)
      last.update_columns(amount_cents: 0)

      Ledger::Mapping.map_primary!(ledger: create(:event).ledger, ledger_item: middle, mapped_by: create(:user))
      perform_enqueued_jobs(only: Subscription::RecomputeJob)

      expect(subscription.reload).to have_attributes(amount_cents: 20_00, last_charged_at: be_within(1.second).of(start))
    end

    it "does not link a charge that moved to another organization while it was being detected" do
      ledger_item = settle(90)
      detection = described_class.new(ledger_item)
      ledger_item.primary_ledger

      Ledger::Mapping.map_primary!(ledger: create(:event).ledger, ledger_item: Ledger::Item.find(ledger_item.id), mapped_by: create(:user))
      detection.run

      expect(ledger_item.reload.subscription).to be_nil
    end
  end

  describe "enqueueing" do
    it "is enqueued when a card charge settles" do
      expect { create_settled_card_charge(user:, stripe_card:, settled_at: start) }.to have_enqueued_job(Subscription::DetectJob).at_least(:once)
    end

    it "is enqueued once when an authorized charge settles" do
      raw_pending_stripe_transaction = create(:raw_pending_stripe_transaction, amount_cents: -45_00, date_posted: Date.current, stripe_card:)
      canonical_pending_transaction = PendingTransactionEngine::CanonicalPendingTransactionService::ImportSingle::Stripe.new(raw_pending_stripe_transaction:).run
      PendingEventMappingEngine::Map::Single::Stripe.new(canonical_pending_transaction:).run
      raw_stripe_transaction = create(:raw_stripe_transaction, stripe_card:, stripe_authorization_id: raw_pending_stripe_transaction.stripe_transaction_id, amount_cents: 45_00)
      canonical_transaction = create(:canonical_transaction, amount_cents: -45_00, transaction_source: raw_stripe_transaction, date: Date.current)

      expect {
        create(:canonical_event_mapping, canonical_transaction:, event:)
        CanonicalPendingTransactionService::Settle.new(canonical_transaction:, canonical_pending_transaction:).run!
      }.to have_enqueued_job(Subscription::DetectJob).exactly(:once)
      expect(canonical_pending_transaction.reload.ledger_item).to be_settled
    end

    it "is enqueued when a settled charge moves to another organization" do
      ledger_item = settle(0)

      expect {
        Ledger::Mapping.map_primary!(ledger: create(:event).ledger, ledger_item:, mapped_by: create(:user))
      }.to have_enqueued_job(Subscription::DetectJob).with(ledger_item)
    end

    it "is not enqueued again when a settled charge is touched" do
      ledger_item = settle(0)

      expect { ledger_item.touch }.not_to have_enqueued_job(Subscription::DetectJob)
    end
  end
end
