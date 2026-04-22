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

  def stub_counts(current:, future: current)
    allow(user).to receive(:transactions_missing_receipt)
      .with(from: Receipt::CARD_LOCKING_START_DATE, to: kind_of(ActiveSupport::TimeWithZone))
      .and_return(double("Relation", count: current))
    allow(user).to receive(:transactions_missing_receipt)
      .with(from: Receipt::CARD_LOCKING_START_DATE)
      .and_return(double("Relation", count: future))
  end

  describe "warning email dedup" do
    it "enqueues a warning email the first time count hits 5" do
      stub_counts(current: 5)

      expect { service.run }.to have_enqueued_mail(CardLockingMailer, :warning).once
    end

    it "does not re-enqueue if count is still 5 on a subsequent run" do
      stub_counts(current: 5)
      service.run

      expect { service.run }.not_to have_enqueued_mail(CardLockingMailer, :warning)
    end

    it "sends a fresh email when count advances from 5 to 7" do
      stub_counts(current: 5)
      service.run

      stub_counts(current: 7)
      expect { service.run }.to have_enqueued_mail(CardLockingMailer, :warning).once
    end

    it "sends at each of 5, 7, and 9 exactly once even with repeat runs between" do
      stub_counts(current: 5)
      expect { 3.times { service.run } }.to have_enqueued_mail(CardLockingMailer, :warning).once

      stub_counts(current: 7)
      expect { 3.times { service.run } }.to have_enqueued_mail(CardLockingMailer, :warning).once

      stub_counts(current: 9)
      expect { 3.times { service.run } }.to have_enqueued_mail(CardLockingMailer, :warning).once
    end

    it "does not notify at off-threshold counts (6, 8)" do
      stub_counts(current: 6)
      expect { service.run }.not_to have_enqueued_mail(CardLockingMailer, :warning)

      stub_counts(current: 8)
      expect { service.run }.not_to have_enqueued_mail(CardLockingMailer, :warning)
    end

    it "re-notifies at the same count after the 25h cache window elapses" do
      stub_counts(current: 5)
      service.run

      travel_to(26.hours.from_now) do
        expect { service.run }.to have_enqueued_mail(CardLockingMailer, :warning).once
      end
    end

    it "dedupes per-user" do
      other_user = create(:user)
      Flipper.enable(:card_locking_2025_06_09, other_user)

      stub_counts(current: 5)
      service.run

      allow(other_user).to receive(:transactions_missing_receipt)
        .with(from: Receipt::CARD_LOCKING_START_DATE, to: kind_of(ActiveSupport::TimeWithZone))
        .and_return(double("Relation", count: 5))
      allow(other_user).to receive(:transactions_missing_receipt)
        .with(from: Receipt::CARD_LOCKING_START_DATE)
        .and_return(double("Relation", count: 5))

      expect {
        described_class.new(user: other_user).run
      }.to have_enqueued_mail(CardLockingMailer, :warning).once
    end
  end

  describe "warning SMS dedup" do
    let(:twilio_send) { instance_double(TwilioMessageService::Send, run!: true) }

    before do
      allow(user).to receive(:phone_number).and_return("+15555555555")
      allow(user).to receive(:phone_number_verified?).and_return(true)
      allow(TwilioMessageService::Send).to receive(:new).and_return(twilio_send)
    end

    it "sends the warning SMS once per threshold and no more" do
      stub_counts(current: 5)
      service.run
      service.run

      expect(TwilioMessageService::Send).to have_received(:new).once
      expect(twilio_send).to have_received(:run!).once
    end
  end

  describe "pre-lock SMS dedup" do
    let(:twilio_send) { instance_double(TwilioMessageService::Send, run!: true) }

    before do
      allow(user).to receive(:phone_number).and_return("+15555555555")
      allow(user).to receive(:phone_number_verified?).and_return(true)
      allow(TwilioMessageService::Send).to receive(:new).and_return(twilio_send)
    end

    it "sends the pre-lock SMS once while future_count is >= 10 and current_count is not a warning threshold" do
      stub_counts(current: 3, future: 11)

      service.run
      service.run
      service.run

      expect(twilio_send).to have_received(:run!).once
    end

    it "re-sends after 25h" do
      stub_counts(current: 3, future: 11)
      service.run

      travel_to(26.hours.from_now) do
        service.run
      end

      expect(twilio_send).to have_received(:run!).twice
    end

    it "does not send when phone is unverified" do
      allow(user).to receive(:phone_number_verified?).and_return(false)
      stub_counts(current: 3, future: 11)

      service.run

      expect(TwilioMessageService::Send).not_to have_received(:new)
    end
  end

  describe "feature flag" do
    it "is a no-op when the flag is disabled for the user" do
      Flipper.disable(:card_locking_2025_06_09, user)
      stub_counts(current: 5)

      expect { service.run }.not_to have_enqueued_mail(CardLockingMailer, :warning)
    end
  end
end
