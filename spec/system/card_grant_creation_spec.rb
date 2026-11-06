# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Card grant creation form", type: :system do
  let(:one_time_use) { "card_grant_one_time_use" }
  let(:pre_authorization) { "card_grant_pre_authorization_required" }

  def visit_form_for(**card_grant_setting)
    event = create(:event, plan_type: Event::Plan::HackClubAffiliate)
    create(:card_grant_setting, event:, **card_grant_setting)
    manager = create(:user)
    create(:organizer_position, user: manager, event:, role: :manager, first_time: false)

    allow_any_instance_of(SessionsHelper)
      .to receive(:find_current_session)
      .and_return(create(:user_session, user: manager))

    visit new_event_card_grant_path(event)
  end

  # Hidden but still checked would submit card-only options on a reimbursement-only grant
  it "hides and clears card-only options while virtual cards are disallowed" do
    visit_form_for
    check one_time_use
    check pre_authorization

    uncheck "card_grant_allow_stripe_card"
    expect(page).to have_no_field(one_time_use)
    expect(page).to have_no_field(pre_authorization)

    check "card_grant_allow_stripe_card"
    expect(page).to have_unchecked_field(one_time_use)
    expect(page).to have_unchecked_field(pre_authorization)
  end

  it "hides card-only options on load when the organization disallows virtual cards by default" do
    visit_form_for(allow_stripe_card: false, allow_reimbursement_report: true)

    expect(page).to have_unchecked_field("card_grant_allow_stripe_card")
    expect(page).to have_checked_field("card_grant_allow_reimbursement_report")
    expect(page).to have_no_field(one_time_use)
    expect(page).to have_no_field(pre_authorization)
  end
end
