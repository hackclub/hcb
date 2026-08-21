# frozen_string_literal: true

require "rails_helper"

RSpec.describe EngineeringAlertMailer, type: :mailer do
  let(:user) { create(:user) }

  before do
    allow(Credentials).to receive(:fetch).with(:SLACK_HCB_ENGR_ALERTS_EMAIL).and_return("engr-alerts@example.com")
  end

  describe "#cards_locked" do
    it "names the user, overdue count, and admin link" do
      mail = described_class.cards_locked(user:, overdue_count: 2, suppressed: false)

      expect(mail.to).to eq(["engr-alerts@example.com"])
      expect(mail.subject).to eq("[Card Locking] #{user.name}'s cards were locked")
      expect(mail.body.encoded).to include(user.email)
      expect(mail.body.encoded).to include(admin_user_url(user))
      expect(mail.body.encoded).not_to include("suppressed")
    end

    it "flags when the user's card locking is currently suppressed" do
      mail = described_class.cards_locked(user:, overdue_count: 2, suppressed: true)

      expect(mail.body.encoded).to include("suppressed")
    end
  end

  describe "#cards_unlocked" do
    it "names the user and admin link" do
      mail = described_class.cards_unlocked(user:, remaining_overdue_count: 0, suppressed: false)

      expect(mail.to).to eq(["engr-alerts@example.com"])
      expect(mail.subject).to eq("[Card Locking] #{user.name}'s cards were unlocked")
      expect(mail.body.encoded).to include(user.email)
      expect(mail.body.encoded).to include(admin_user_url(user))
    end

    it "flags when the user's card locking is currently suppressed" do
      mail = described_class.cards_unlocked(user:, remaining_overdue_count: 0, suppressed: true)

      expect(mail.body.encoded).to include("suppressed")
    end

    it "does not report an anomaly when suppressed, even with overdue charges remaining" do
      # Admin suppression is a supported action that unlocks without
      # resolving receipts by design -- not a violated precondition.
      expect(Rails.error).not_to receive(:unexpected)

      described_class.cards_unlocked(user:, remaining_overdue_count: 1, suppressed: true).message
    end

    it "does not report an anomaly when no overdue charges remain" do
      expect(Rails.error).not_to receive(:unexpected)

      described_class.cards_unlocked(user:, remaining_overdue_count: 0, suppressed: false).message
    end

    # Rails.error.unexpected raises (wrapped) instead of just reporting
    # whenever Rails.error.debug_mode is true -- true by default in
    # development/test (config.consider_all_requests_local), false in
    # production. So a genuine (non-suppressed) violation fails loudly here...
    it "raises a violated-precondition error for a genuine (non-suppressed) unlock with overdue charges remaining" do
      # .message forces the lazy MessageDelivery proxy to actually run the
      # mailer action body; a bare method call alone never executes it.
      expect { described_class.cards_unlocked(user:, remaining_overdue_count: 1, suppressed: false).message }
        .to raise_error(ActiveSupport::ErrorReporter::UnexpectedError, /unlocked with 1 overdue/)
    end

    # ...but only reports (and still sends the alert) in production, where
    # Rails.error.debug_mode is false and mail delivery must not be disrupted.
    it "reports without raising and still sends the alert in production" do
      # unexpected checks the real @debug_mode ivar directly, so stubbing the
      # reader method has no effect -- must actually flip and restore it.
      original_debug_mode = Rails.error.debug_mode
      Rails.error.debug_mode = false
      begin
        expect(Rails.error).to receive(:unexpected).with(
          a_string_including("unlocked with 1 overdue"), context: { user_id: user.id, remaining_overdue_count: 1 }
        ).and_call_original

        mail = described_class.cards_unlocked(user:, remaining_overdue_count: 1, suppressed: false)

        expect(mail.body.encoded).to include("still remain")
      ensure
        Rails.error.debug_mode = original_debug_mode
      end
    end
  end
end
