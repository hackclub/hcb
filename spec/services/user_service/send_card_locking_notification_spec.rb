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

  def stub_warning_state(warning_ids: {}, has_violations: false)
    User::CARD_LOCKING_WARNING_THRESHOLDS.each do |threshold|
      hcb_codes = Array(warning_ids[threshold]).map { |id| instance_double(HcbCode, id:) }

      allow(user).to receive(:card_locking_receipts_reaching_warning_threshold)
        .with(threshold:, now: kind_of(ActiveSupport::TimeWithZone))
        .and_return(hcb_codes)
    end

    allow(user).to receive(:has_missing_receipt_violations?)
      .with(now: kind_of(ActiveSupport::TimeWithZone))
      .and_return(has_violations)
  end

  describe "warning email dedup" do
    it "enqueues a warning email when a receipt crosses the 48-hour threshold" do
      stub_warning_state(warning_ids: { 48.hours => [1] })

      expect { service.run }.to have_enqueued_mail(CardLockingMailer, :warning).once
    end

    it "does not re-enqueue the same 48-hour warning on a subsequent run" do
      stub_warning_state(warning_ids: { 48.hours => [1] })
      service.run

      expect { service.run }.not_to have_enqueued_mail(CardLockingMailer, :warning)
    end

    it "sends a fresh warning when the same receipt later crosses the 71-hour threshold" do
      stub_warning_state(warning_ids: { 48.hours => [1] })
      service.run

      stub_warning_state(warning_ids: { 71.hours => [1] })

      expect { service.run }.to have_enqueued_mail(CardLockingMailer, :warning).once
    end

    it "deduplicates every receipt that crosses a threshold in the same run" do
      stub_warning_state(warning_ids: { 48.hours => [1, 2] })

      expect { service.run }.to have_enqueued_mail(CardLockingMailer, :warning).once
      expect { service.run }.not_to have_enqueued_mail(CardLockingMailer, :warning)
    end

    it "sends a daily digest while violations exist" do
      stub_warning_state(has_violations: true)

      expect { service.run }.to have_enqueued_mail(CardLockingMailer, :warning).once
      expect { service.run }.not_to have_enqueued_mail(CardLockingMailer, :warning)

      travel_to(26.hours.from_now) do
        expect { service.run }.to have_enqueued_mail(CardLockingMailer, :warning).once
      end
    end
  end

  describe "warning SMS dedup" do
    let(:twilio_send) { instance_double(TwilioMessageService::Send, run!: true) }

    before do
      allow(user).to receive(:phone_number).and_return("+15555555555")
      allow(user).to receive(:phone_number_verified?).and_return(true)
      allow(TwilioMessageService::Send).to receive(:new).and_return(twilio_send)
    end

    it "sends the 48-hour warning SMS once per threshold crossing" do
      stub_warning_state(warning_ids: { 48.hours => [1] })

      service.run
      service.run

      expect(twilio_send).to have_received(:run!).once
    end

    it "sends a daily digest SMS while violations exist" do
      stub_warning_state(has_violations: true)

      service.run
      service.run

      expect(twilio_send).to have_received(:run!).once

      travel_to(26.hours.from_now) do
        service.run
      end

      expect(twilio_send).to have_received(:run!).twice
    end

    it "does not send when the phone is unverified" do
      allow(user).to receive(:phone_number_verified?).and_return(false)
      stub_warning_state(warning_ids: { 48.hours => [1] })

      service.run

      expect(TwilioMessageService::Send).not_to have_received(:new)
    end
  end

  describe "locked users" do
    before { user.update!(cards_locked: true) }

    it "keeps sending the violation digest" do
      stub_warning_state(has_violations: true)

      expect { service.run }.to have_enqueued_mail(CardLockingMailer, :warning).once
    end

    it "does not send approaching-deadline warnings" do
      stub_warning_state(warning_ids: { 48.hours => [1] })

      expect { service.run }.not_to have_enqueued_mail(CardLockingMailer, :warning)
    end
  end

  describe "guard rails" do
    it "is a no-op when the feature flag is disabled for the user" do
      Flipper.disable(:card_locking_2025_06_09, user)
      stub_warning_state(warning_ids: { 48.hours => [1] })

      expect { service.run }.not_to have_enqueued_mail(CardLockingMailer, :warning)
    end
  end
end
