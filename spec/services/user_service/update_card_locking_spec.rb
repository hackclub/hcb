# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserService::UpdateCardLocking, type: :service do
  let(:user) { create(:user) }

  before do
    Flipper.enable(:card_locking_2025_06_09, user)
  end

  it "locks and notifies when a charge is overdue" do
    allow(user).to receive(:card_locking_has_overdue_charge?).and_return(true)
    allow(user).to receive(:card_locking_overdue_charges).and_return(HcbCode.none)
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

  it "is a no-op in unlock_only mode when the card is already unlocked" do
    allow(user).to receive(:card_locking_has_overdue_charge?).and_return(false)
    expect { described_class.new(user:, unlock_only: true).run }.not_to(change { user.reload.cards_locked? })
  end

  it "respects an active admin suppression (does not lock)" do
    allow(user).to receive(:card_locking_suppressed?).and_return(true)
    allow(user).to receive(:card_locking_has_overdue_charge?).and_return(true)
    expect { described_class.new(user:).run }.not_to(change { user.reload.cards_locked? })
  end

  it "is a no-op when the master flag is disabled" do
    Flipper.disable(:card_locking_2025_06_09, user)
    allow(user).to receive(:card_locking_has_overdue_charge?).and_return(true)
    expect { described_class.new(user:).run }.not_to(change { user.reload.cards_locked? })
  end
end
