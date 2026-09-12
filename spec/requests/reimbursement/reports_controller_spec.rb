# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reimbursement::ReportsController", type: :request do
  # Submitting the public reimbursement form creates a User without a session,
  # so it carries the same requirement as the signup forms: the form has to
  # have been rendered first.
  let(:event) { create(:event, public_reimbursement_page_enabled: true) }

  def visit_public_form
    get reimbursement_start_reimbursement_report_path(event_name: event.slug)
  end

  def submit(email:)
    post reimbursement_reports_path, params: {
      reimbursement_report: { event_id: event.id, email:, report_name: "Probe report" }
    }
  end

  describe "POST /reimbursement/reports" do
    it "creates no user when the client never rendered the form" do
      email = "scripted-#{SecureRandom.hex(4)}@example.invalid"

      expect { submit(email:) }.to change { User.count }.by(0)

      expect(User.find_by(email:)).to be_nil
    end

    it "creates the report's user once the form has been rendered" do
      email = "claimant-#{SecureRandom.hex(4)}@example.invalid"
      visit_public_form

      expect { submit(email:) }.to change { User.count }.by(1)

      expect(User.find_by(email:)).to be_present
    end
  end
end
