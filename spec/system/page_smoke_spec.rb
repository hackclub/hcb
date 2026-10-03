# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organization pages", type: :system do
  include SystemSessionSupport

  let(:user) { create(:user, phone_number: "+18556254225") }
  let(:event) { create(:event, :with_positive_balance) }

  before do
    create(:organizer_position_invite, :accepted, event:, user:)
    user.organizer_positions.sole.update!(first_time: false)
    sign_in(user)
  end

  %i[
    event_path event_transactions_path event_team_path event_cards_overview_path event_donation_overview_path
    event_invoices_path event_reimbursements_path event_transfers_path event_check_deposits_path
    event_documentation_path event_statements_path event_announcement_overview_path event_promotions_path event_edit_path
  ].each do |path|
    it "renders #{path} and all its lazy sections without JS errors" do
      visit public_send(path, event)
      page.scroll_to(:bottom) # lazy frames only load once scrolled into view

      expect(page).to have_no_css("turbo-frame[src]:not([complete])")
      expect(page).to have_no_text("Content missing")
    end
  end
end
