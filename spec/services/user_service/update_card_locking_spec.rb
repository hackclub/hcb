# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserService::UpdateCardLocking, type: :service do
  let(:user) { create(:user) }

  before do
    Flipper.enable(:card_locking)
  end

  it "locks and notifies when a charge is overdue" do
    allow(user).to receive(:card_locking_has_overdue_charge?).and_return(true)
    allow(user).to receive(:card_locking_overdue_charges).and_return(Ledger::Item.none)
    expect {
      described_class.new(user:).run
    }.to change { user.reload.cards_locked? }.from(false).to(true)
     .and have_enqueued_mail(CardLockingMailer, :cards_locked)
     .and have_enqueued_job(User::SendSmsJob)
  end

  it "always unlocks when nothing is overdue" do
    user.update!(cards_locked: true)
    allow(user).to receive(:card_locking_has_overdue_charge?).and_return(false)
    expect {
      described_class.new(user:).run
    }.to change { user.reload.cards_locked? }.from(true).to(false)
     .and have_enqueued_mail(CardLockingMailer, :cards_unlocked)
  end

  it "does NOT unlock in unlock_only mode while a charge is still overdue" do
    user.update!(cards_locked: true)
    allow(user).to receive(:card_locking_has_overdue_charge?).and_return(true)
    expect {
      described_class.new(user:, unlock_only: true).run
    }.not_to(change { user.reload.cards_locked? })
  end

  it "confirms progress by SMS when an upload still leaves charges overdue" do
    user.update!(cards_locked: true)
    allow(user).to receive(:card_locking_has_overdue_charge?).and_return(true)
    overdue = instance_double(ActiveRecord::Relation, exists?: true)
    allow(overdue).to receive(:count).and_return(2)
    allow(user).to receive(:card_locking_overdue_charges).and_return(overdue)

    expect {
      described_class.new(user:, unlock_only: true, notify_progress: true).run
    }.to have_enqueued_job(User::SendSmsJob)
    expect(user.reload.cards_locked?).to be(true)
  end

  it "stays silent on a plain unlock_only run that leaves charges overdue" do
    user.update!(cards_locked: true)
    allow(user).to receive(:card_locking_has_overdue_charge?).and_return(true)

    expect {
      described_class.new(user:, unlock_only: true).run
    }.not_to have_enqueued_job(User::SendSmsJob)
  end

  it "unlocks in unlock_only mode when nothing is overdue" do
    user.update!(cards_locked: true)
    allow(user).to receive(:card_locking_has_overdue_charge?).and_return(false)
    expect {
      described_class.new(user:, unlock_only: true).run
    }.to change { user.reload.cards_locked? }.from(true).to(false)
  end

  # The unlock decision is made on persisted deadlines. A charge that has not
  # been materialized yet (its settlement job still queued, or every charge
  # right after deadlines moved onto ledger items) has none, so without a
  # refresh it would read as on time and the cards would unlock with it overdue.
  describe "in unlock_only mode" do
    include_context "card locking charges"

    it "refreshes deadlines before deciding, so a charge with none yet keeps the cards locked" do
      charge = create_settled_card_charge(user:, settled_at: 10.days.ago)
      expect(charge.receipt_due_at).to be_nil
      user.update!(cards_locked: true)

      expect {
        described_class.new(user:, unlock_only: true).run
      }.not_to(change { user.reload.cards_locked? })
      expect(charge.reload.receipt_due_at).to be_within(2.seconds).of(10.days.ago + 7.days)
    end
  end

  it "is a no-op in unlock_only mode when the card is already unlocked" do
    allow(user).to receive(:card_locking_has_overdue_charge?).and_return(false)
    expect { described_class.new(user:, unlock_only: true).run }.not_to(change { user.reload.cards_locked? })
  end

  it "respects an active admin suppression (does not lock)" do
    allow(user).to receive(:card_locking_suppressed?).and_return(true)
    allow(user).to receive(:card_locking_has_overdue_charge?).and_return(true)
    expect { described_class.new(user:).run }.not_to(change { user.reload.cards_locked? })
  end

  # A suppression unlock is temporary and the receipts are still overdue, so the
  # notification has to carry the expiry rather than the plain "cards work again".
  it "tells a cardholder unlocked by suppression when the exception ends" do
    user.update!(cards_locked: true, card_locking_suppressed_until: 24.hours.from_now)
    allow(user).to receive(:card_locking_has_overdue_charge?).and_return(true)
    allow(user).to receive(:card_locking_overdue_charges).and_return(Ledger::Item.none)

    expect {
      described_class.new(user:).run
    }.to change { user.reload.cards_locked? }.from(true).to(false)
     .and have_enqueued_mail(CardLockingMailer, :cards_unlocked)
     .with(a_hash_including(suppressed_until: be_present))
  end

  it "does not lock an overdue cardholder when the feature is disabled" do
    Flipper.disable(:card_locking)
    allow(user).to receive(:card_locking_has_overdue_charge?).and_return(true)
    expect { described_class.new(user:).run }.not_to(change { user.reload.cards_locked? })
  end

  # The kill switch releases locked cardholders rather than freezing them. Were it
  # an early return, switching the feature off would leave them locked with no way
  # to unlock by uploading.
  it "unlocks an already-locked cardholder when the feature is disabled" do
    user.update!(cards_locked: true)
    Flipper.disable(:card_locking)
    allow(user).to receive(:card_locking_has_overdue_charge?).and_return(true)

    expect {
      described_class.new(user:).run
    }.to change { user.reload.cards_locked? }.from(true).to(false)
     .and have_enqueued_mail(CardLockingMailer, :cards_unlocked)
  end
end
