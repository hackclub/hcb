# frozen_string_literal: true

require "rails_helper"

# `invisible_captcha` stores one global timestamp in the session, so a token
# seeded by any guarded form is accepted by every other guarded endpoint. These
# cover the per-form record that closes that.
RSpec.describe "form provenance", type: :request do
  describe "reimbursement reports" do
    let(:event) { create(:event, public_reimbursement_page_enabled: true) }

    def submit(email:, event_id: event.id)
      post reimbursement_reports_path, params: {
        reimbursement_report: { event_id:, email:, report_name: "Probe report" }
      }
    end

    it "rejects a token seeded by a different form" do
      email = "cross-path-#{SecureRandom.hex(4)}@example.invalid"
      get auth_users_path # the login form, not the reimbursement one

      expect { submit(email:) }.to change { User.count }.by(0)

      expect(User.find_by(email:)).to be_nil
    end

    it "accepts the form's own token" do
      email = "claimant-#{SecureRandom.hex(4)}@example.invalid"
      get reimbursement_start_reimbursement_report_path(event_name: event.slug)

      expect { submit(email:) }.to change { User.count }.by(1)
    end

    it "spends the record, so one render buys one submission" do
      get reimbursement_start_reimbursement_report_path(event_name: event.slug)
      submit(email: "first-#{SecureRandom.hex(4)}@example.invalid")

      second = "replay-#{SecureRandom.hex(4)}@example.invalid"
      expect { submit(email: second) }.to change { User.count }.by(0)
    end

    it "creates no user for an organization without a public reimbursement page" do
      closed = create(:event, public_reimbursement_page_enabled: false)
      email = "denied-#{SecureRandom.hex(4)}@example.invalid"
      get reimbursement_start_reimbursement_report_path(event_name: event.slug)

      expect { submit(email:, event_id: closed.id) }.to change { User.count }.by(0)

      expect(User.find_by(email:)).to be_nil
    end
  end

  describe "logins" do
    it "rejects a token seeded by a different form" do
      email = "cross-path-#{SecureRandom.hex(4)}@example.invalid"
      event = create(:event, public_reimbursement_page_enabled: true)
      get reimbursement_start_reimbursement_report_path(event_name: event.slug)

      expect {
        post "/logins", params: { email:, login: { return_to: "/" } }
      }.to change { User.count }.by(0)
    end

    it "accepts the login form's own token" do
      email = "signup-#{SecureRandom.hex(4)}@example.invalid"
      get auth_users_path

      expect {
        post "/logins", params: { email:, login: { return_to: "/" } }
      }.to change { User.count }.by(1)
    end
  end
end
