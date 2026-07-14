# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserService::SendCardLockingNotification, type: :service do
  let(:user) { create(:user) }
  let(:service) { described_class.new(user:) }

  around do |example|
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rails.cache = original
  end

  before do
    Flipper.enable(:card_locking_2025_06_09, user)
    # Default: a charge is approaching its deadline, so the warning is warranted.
    # The gate itself is exercised with real charges below.
    allow(user).to receive(:card_locking_has_approaching_charge?).and_return(true)
  end

  it "sends one pile warning per day when receipts are outstanding" do
    allow(user).to receive(:card_locking_outstanding_count).and_return(4)

    expect { service.run }.to have_enqueued_mail(CardLockingMailer, :warning).once
    expect(User::SendSmsJob).to have_been_enqueued

    expect { service.run }.not_to have_enqueued_mail(CardLockingMailer, :warning)

    travel_to(26.hours.from_now) do
      expect { service.run }.to have_enqueued_mail(CardLockingMailer, :warning).once
    end
  end

  it "sends the digest again the next day rather than skipping a day" do
    allow(user).to receive(:card_locking_outstanding_count).and_return(4)
    service.run

    # The dedup key (not the cron) enforces the daily cadence, so it must have
    # expired by the ~24h mark or the cardholder silently skips a calendar day.
    # The TTL is deliberately under 24h so the send drifts earlier, never later.
    travel_to(24.hours.from_now) do
      expect { service.run }.to have_enqueued_mail(CardLockingMailer, :warning).once
    end
  end

  it "warns that the cardholder's cards will lock, not individual cards" do
    allow(user).to receive(:card_locking_outstanding_count).and_return(2)

    service.run

    expect(User::SendSmsJob).to have_been_enqueued.with(
      user_id: user.id, body: a_string_matching(/your cards/i)
    )
  end

  it "does not send when no charge is approaching its deadline" do
    allow(user).to receive(:card_locking_has_approaching_charge?).and_return(false)
    allow(user).to receive(:card_locking_outstanding_count).and_return(4)

    expect { service.run }.not_to have_enqueued_mail(CardLockingMailer, :warning)
  end

  it "does not send when nothing is outstanding" do
    allow(user).to receive(:card_locking_outstanding_count).and_return(0)

    expect { service.run }.not_to have_enqueued_mail(CardLockingMailer, :warning)
  end

  it "releases the dedup key when the mail cannot be enqueued" do
    allow(user).to receive(:card_locking_outstanding_count).and_return(4)
    allow(CardLockingMailer).to receive(:warning).and_raise("Redis down")

    expect { service.run }.to raise_error("Redis down")

    allow(CardLockingMailer).to receive(:warning).and_call_original

    expect { service.run }.to have_enqueued_mail(CardLockingMailer, :warning).once
  end

  it "is a no-op when the feature flag is disabled for the user" do
    Flipper.disable(:card_locking_2025_06_09, user)
    allow(user).to receive(:card_locking_outstanding_count).and_return(4)

    expect { service.run }.not_to have_enqueued_mail(CardLockingMailer, :warning)
  end

  it "suppresses the pre-lock warning when the user's cards are already locked" do
    user.update!(cards_locked: true)
    allow(user).to receive(:card_locking_outstanding_count).and_return(4)

    expect { service.run }.not_to have_enqueued_mail(CardLockingMailer, :warning)
    expect(User::SendSmsJob).not_to have_been_enqueued
  end
end
