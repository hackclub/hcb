# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserService::SendCardLockingNotification, "under an admin exception", type: :service do
  include_context "card locking charges"

  let(:now) { Time.zone.parse("2026-10-10 12:00:00") }

  # The suite runs against a null cache store, but every dedup rule here is
  # enforced by the cache, so it has to be real for these to mean anything.
  # Both of these are global state, and both are restored in an ensure so a
  # failing example cannot leak them into the rest of the suite. The clock in
  # particular: examples here travel forward to age a dedup key, and leaving it
  # in 2026-10 breaks unrelated specs whose factories validate against Time.now.
  around do |example|
    original_cache = Rails.cache
    # The suite runs against a null cache store, but every dedup rule here is
    # enforced by the cache, so it has to be real for these to mean anything.
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    travel_to(now)
    example.run
  ensure
    travel_back
    Rails.cache = original_cache
  end

  # The shared context enables the rollout stage flag, not the kill switch.
  before { Flipper.enable(:card_locking) }

  def enqueued_mailer_methods
    ActiveJob::Base.queue_adapter.enqueued_jobs
                   .select { |job| job[:job] == MailDeliveryJob && job[:args].first == "CardLockingMailer" }
                   .map { |job| job[:args].second }
  end

  def enqueued_sms_count
    ActiveJob::Base.queue_adapter.enqueued_jobs.count { |job| job[:job] == User::SendSmsJob }
  end

  def overdue_charge
    settled_at = 10.days.ago
    create_settled_card_charge(user:, settled_at:).tap do |charge|
      charge.update_columns(card_charge_settled_at: settled_at, receipt_due_at: 1.day.ago)
    end
  end

  def suppress_until(time)
    user.update!(card_locking_suppressed_until: time)
  end

  # Clear first so assertions cover only what this run enqueued. reload because
  # the cardholder association is memoized before the charge creates it, without
  # which card_locking_overdue_charges returns nothing.
  def run(at: now)
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
    described_class.new(user: user.reload, now: at).run
  end

  it "does not send the ordinary pre-lock digest, which contradicts the exception" do
    overdue_charge
    suppress_until(now + 10.days)

    expect { run }.not_to have_enqueued_mail(CardLockingMailer, :warning)
  end

  describe "the reminder, while there is plenty of time left" do
    before do
      overdue_charge
      suppress_until(now + 10.days)
    end

    it "sends by email only, holding SMS back for the ending notices" do
      run

      expect(enqueued_mailer_methods).to eq(["suppression_reminder"])
      expect(enqueued_sms_count).to eq(0)
    end

    it "does not repeat within the reminder interval" do
      run
      soon = now + CardLocking::SUPPRESSION_REMINDER_INTERVAL - 1.hour
      travel_to(soon)

      expect { run(at: soon) }.not_to have_enqueued_mail(CardLockingMailer, :suppression_reminder)
    end

    it "repeats once the interval has passed" do
      run
      later = now + CardLocking::SUPPRESSION_REMINDER_INTERVAL + 1.minute
      travel_to(later)

      expect { run(at: later) }.to have_enqueued_mail(CardLockingMailer, :suppression_reminder)
    end
  end

  describe "the ending notices" do
    it "sends the 48h notice by email and SMS" do
      overdue_charge
      suppress_until(now + 40.hours)

      run

      expect(enqueued_mailer_methods).to eq(["suppression_ending"])
      expect(enqueued_sms_count).to eq(1)
    end

    it "sends the final notice within the last hour" do
      overdue_charge
      suppress_until(now + 30.minutes)

      expect { run }.to have_enqueued_mail(CardLockingMailer, :suppression_ending)
    end

    it "sends each stage only once for a given deadline" do
      overdue_charge
      suppress_until(now + 40.hours)
      run

      expect { run(at: now + 5.minutes) }.not_to have_enqueued_mail(CardLockingMailer, :suppression_ending)
    end

    # A plain "already warned" flag would swallow the warning for the new date.
    it "re-sends after the exception is extended" do
      overdue_charge
      suppress_until(now + 40.hours)
      run

      suppress_until(now + 44.hours)

      expect { run(at: now + 5.minutes) }.to have_enqueued_mail(CardLockingMailer, :suppression_ending)
    end
  end

  # A 5 day exception is the colliding case: its 3 day reminder falls exactly on
  # the 48h notice.
  it "never sends a reminder alongside an ending notice" do
    overdue_charge
    suppress_until(now + 5.days)
    at = now + 3.days
    travel_to(at)

    run(at:)

    expect(enqueued_mailer_methods).to eq(["suppression_ending"])
  end

  it "sends nothing once the cardholder has uploaded everything" do
    suppress_until(now + 10.days)

    expect { run }.not_to have_enqueued_mail(CardLockingMailer, :suppression_reminder)
    expect { run }.not_to have_enqueued_mail(CardLockingMailer, :suppression_ending)
  end
end
