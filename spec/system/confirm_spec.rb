# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Confirm dialogs", type: :system do
  include SystemSessionSupport

  let(:user) { create(:user, phone_number: "+18556254225") }
  let(:event) { create(:event) }
  let(:dialog) { ".swal-modal" }

  before do
    create(:organizer_position_invite, :accepted, event:, user:, role: :manager)
    user.organizer_positions.sole.update!(first_time: false)
    sign_in(user)
  end

  context "with a turbo_confirm link" do
    let!(:report) { create(:reimbursement_report, user:, event:) }
    let(:delete_button) { find("[aria-label='Delete this report.']") }

    before do
      visit reimbursement_report_path(report)
      delete_button.click
    end

    it "leaves the record alone when cancelled and asks again next time" do
      within(dialog) { click_on "Cancel" }
      expect(page).to have_no_css(dialog)

      delete_button.click
      expect(page).to have_css(dialog)
      expect(page).to have_current_path(reimbursement_report_path(report))
      expect(Reimbursement::Report.exists?(report.id)).to be(true)
    end

    it "deletes the record once confirmed" do
      within(dialog) { click_on "Confirm" }

      expect(page).to have_current_path(event_reimbursements_path(event))
      expect(Reimbursement::Report.exists?(report.id)).to be(false)
    end
  end

  context "with the confirm controller on a switch" do
    before do
      event.create_donation_goal!(amount_cents: 100_00, tracking_since: Time.current)
      visit edit_event_path(event, tab: "donations")
      uncheck "donation_goal_enabled", allow_label_click: true
    end

    it "turns the switch back on when cancelled" do
      within(dialog) { click_on "Cancel" }

      expect(page).to have_checked_field("donation_goal_enabled", visible: :all)
      expect(page).to have_field("amount_cents", with: "100")
      expect(event.reload.donation_goal).to be_present
    end

    it "submits the form once confirmed" do
      within(dialog) { click_on "Remove" }

      expect(page).to have_text("Donation goal removed successfully.")
      expect(event.reload.donation_goal).to be_nil
    end
  end
end
