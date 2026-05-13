# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserService::UpdateCardLocking, type: :service do
  let(:user) { create(:user) }
  let(:service) { described_class.new(user:) }

  before do
    Flipper.enable(:card_locking_2025_06_09, user)
  end

  describe "#run" do
    it "locks cards when the policy says they should lock" do
      allow(user).to receive(:cards_should_lock?).and_return(true)
      allow(user).to receive(:card_locking_missing_receipt_violations).and_return([double, double])

      expect {
        service.run
      }.to change { user.reload.cards_locked? }.from(false).to(true)
    end

    it "unlocks cards in unlock-only mode once violations are cleared" do
      user.update!(cards_locked: true)

      service = described_class.new(user:, unlock_only: true)

      allow(user).to receive(:has_missing_receipt_violations?).and_return(false)

      expect {
        service.run
      }.to change { user.reload.cards_locked? }.from(true).to(false)
    end

    it "does not unlock cards in unlock-only mode if violations remain" do
      user.update!(cards_locked: true)

      service = described_class.new(user:, unlock_only: true)

      allow(user).to receive(:cards_should_lock?).and_return(true)

      expect {
        service.run
      }.not_to(change { user.reload.cards_locked? })
    end

    it "unlocks cards in unlock-only mode when the full policy no longer requires a lock" do
      user.update!(cards_locked: true)

      service = described_class.new(user:, unlock_only: true)

      allow(user).to receive(:cards_should_lock?).and_return(false)

      expect {
        service.run
      }.to change { user.reload.cards_locked? }.from(true).to(false)
    end

    it "is a no-op when the flag is disabled for the user" do
      Flipper.disable(:card_locking_2025_06_09, user)
      allow(user).to receive(:cards_should_lock?).and_return(true)

      expect {
        service.run
      }.not_to(change { user.reload.cards_locked? })
    end
  end
end
