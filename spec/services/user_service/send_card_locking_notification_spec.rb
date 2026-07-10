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
  end

  it "sends one pile warning per day when receipts are outstanding" do
    allow(user).to receive(:card_locking_outstanding_count).and_return(4)

    expect { service.run }.to have_enqueued_mail(CardLockingMailer, :warning).once
    expect(CardLocking::SendSmsJob).to have_been_enqueued

    expect { service.run }.not_to have_enqueued_mail(CardLockingMailer, :warning)

    travel_to(26.hours.from_now) do
      expect { service.run }.to have_enqueued_mail(CardLockingMailer, :warning).once
    end
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
end
