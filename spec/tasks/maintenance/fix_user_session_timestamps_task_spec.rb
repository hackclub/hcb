# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::FixUserSessionTimestampsTask, versioning: true do
  it "restores timestamps for a previously signed-out session" do
    travel_to Time.zone.parse("2026-04-01 12:00:00") do
      session = create(:user_session, expiration_at: 2.months.ago)
      session.update!(signed_out_at: 1.month.ago, expiration_at: 1.month.ago)
      original_expiration_at = session.expiration_at
      original_signed_out_at = session.signed_out_at

      travel 5.days do
        signed_out_at = Time.current
        session.update_columns(signed_out_at:, expiration_at: signed_out_at - 0.1.seconds)

        expect(described_class.new.collection).to include(session)
        expect { described_class.new.process(session) }.to change { session.versions.count }.by(1)

        expect(session.reload.expiration_at).to eq(original_expiration_at)
        expect(session.signed_out_at).to eq(original_signed_out_at)
      end
    end
  end

  it "clears the erroneous sign-out time for a naturally expired session" do
    travel_to Time.zone.parse("2026-04-01 12:00:00") do
      session = create(:user_session, expiration_at: 2.months.ago)
      original_expiration_at = session.expiration_at

      travel 1.day do
        session.update_columns(signed_out_at: Time.current, expiration_at: Time.current)

        described_class.new.process(session)

        expect(session.reload.expiration_at).to eq(original_expiration_at)
        expect(session.signed_out_at).to be_nil
      end
    end
  end

  it "does not restore an active session that was legitimately signed out" do
    travel_to Time.zone.parse("2026-04-01 12:00:00") do
      session = create(:user_session, expiration_at: 1.day.from_now)

      travel 1.second do
        signed_out_at = Time.current
        session.update_columns(signed_out_at:, expiration_at: signed_out_at)

        described_class.new.process(session)

        expect(session.reload.expiration_at).to eq(signed_out_at)
        expect(session.signed_out_at).to eq(signed_out_at)
      end
    end
  end

  it "does not undo a direct logout recorded in PaperTrail" do
    travel_to Time.zone.parse("2026-04-01 12:00:00") do
      session = create(:user_session, expiration_at: 2.months.ago)
      session.update!(signed_out_at: Time.current, expiration_at: Time.current)
      signed_out_at = session.signed_out_at
      expiration_at = session.expiration_at

      described_class.new.process(session)

      expect(session.reload.expiration_at).to eq(expiration_at)
      expect(session.signed_out_at).to eq(signed_out_at)
    end
  end

  it "does not undo timestamps written when the user was locked" do
    travel_to Time.zone.parse("2026-04-01 12:00:00") do
      user = create(:user, verified: true)
      session = create(:user_session, user:, verified: true, expiration_at: 2.months.ago)

      travel 1.second do
        user.lock!
        signed_out_at = session.reload.signed_out_at
        expiration_at = session.expiration_at

        described_class.new.process(session)

        expect(session.reload.expiration_at).to eq(expiration_at)
        expect(session.signed_out_at).to eq(signed_out_at)
      end
    end
  end

  it "does not undo a zombie session revocation" do
    travel_to Time.zone.parse("2026-04-01 12:00:00") do
      user = create(:user, verified: true)
      session = create(:user_session, user:, verified: true, last_seen_at: 10.minutes.ago, expiration_at: 1.day.from_now)
      session.update_columns(verified: false)
      session.update_session_timestamps

      travel 3.days do
        signed_out_at = Time.current
        session.update_columns(signed_out_at:, expiration_at: signed_out_at)

        described_class.new.process(session)

        expect(session.reload.expiration_at).to eq(signed_out_at)
        expect(session.signed_out_at).to eq(signed_out_at)
      end
    end
  end

  it "restores an expiry captured by a PaperTrail snapshot after session activity" do
    travel_to Time.zone.parse("2026-04-01 12:00:00") do
      session = create(:user_session, expiration_at: 1.day.ago)

      travel 1.second do
        expiration_at = 1.hour.from_now
        session.update_columns(last_seen_at: Time.current, expiration_at:)

        travel 1.second do
          session.update!(device_info: "Recent device")
        end
      end

      travel 2.days do
        signed_out_at = Time.current
        session.update_columns(signed_out_at:, expiration_at: signed_out_at)

        described_class.new.process(session)

        expect(session.reload.expiration_at).to eq(expiration_at)
        expect(session.signed_out_at).to be_nil
      end
    end
  end

  it "does not restore when activity after the latest snapshot may have extended the expiration" do
    travel_to Time.zone.parse("2026-04-01 12:00:00") do
      session = create(:user_session, expiration_at: 1.day.from_now)
      last_seen_at = 1.second.from_now
      session.update_columns(last_seen_at:, expiration_at: 3.days.from_now)

      travel 2.days do
        signed_out_at = Time.current
        session.update_columns(signed_out_at:, expiration_at: signed_out_at)

        described_class.new.process(session)

        expect(session.reload.expiration_at).to eq(signed_out_at)
        expect(session.signed_out_at).to eq(signed_out_at)
      end
    end
  end
end
