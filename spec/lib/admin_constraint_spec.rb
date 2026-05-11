# frozen_string_literal: true

require "rails_helper"
require "admin_constraint"

RSpec.describe AdminConstraint do
  describe ".matches?" do
    include_context "with stubbed session_token cookie"

    context "when there is no session token cookie" do
      let(:session_token) { nil }

      it "returns false" do
        expect(described_class.matches?(request)).to eq(false)
      end
    end

    context "when the session token does not match any session" do
      let(:session_token) { "no-such-token" }

      it "returns false" do
        expect(described_class.matches?(request)).to eq(false)
      end
    end

    context "when the session belongs to an admin user" do
      let(:user) { create(:user, :make_admin) }
      let!(:session) { create(:user_session, verified: true, user:, expiration_at: 7.days.from_now) }
      let(:session_token) { session.session_token }

      it "returns true" do
        expect(described_class.matches?(request)).to eq(true)
      end
    end

    context "when the session belongs to a non-admin user" do
      let(:user) { create(:user) }
      let!(:session) { create(:user_session, verified: true, user:, expiration_at: 7.days.from_now) }
      let(:session_token) { session.session_token }

      it "returns false" do
        expect(described_class.matches?(request)).to eq(false)
      end
    end

    context "when the session belongs to an auditor user (read-only role)" do
      let(:user) { create(:user, access_level: :auditor) }
      let!(:session) { create(:user_session, verified: true, user:, expiration_at: 7.days.from_now) }
      let(:session_token) { session.session_token }

      it "returns false" do
        expect(described_class.matches?(request)).to eq(false)
      end
    end

    context "when the session has expired" do
      let(:user) { create(:user, :make_admin) }
      let!(:session) { create(:user_session, verified: true, user:, expiration_at: 1.minute.ago) }
      let(:session_token) { session.session_token }

      it "returns false" do
        expect(described_class.matches?(request)).to eq(false)
      end
    end

    context "when the admin user has pretend_is_not_admin set" do
      let(:user) { create(:user, :make_admin, pretend_is_not_admin: true) }
      let!(:session) { create(:user_session, verified: true, user:, expiration_at: 7.days.from_now) }
      let(:session_token) { session.session_token }

      it "returns false" do
        expect(described_class.matches?(request)).to eq(false)
      end
    end

    context "when the session has been signed out" do
      let(:user) { create(:user, :make_admin) }
      let!(:session) do
        create(:user_session, verified: true, user:,
                              expiration_at: 1.minute.ago,
                              signed_out_at: 1.minute.ago)
      end
      let(:session_token) { session.session_token }

      it "returns false" do
        expect(described_class.matches?(request)).to eq(false)
      end
    end
  end
end
