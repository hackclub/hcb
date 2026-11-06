# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Card grant invitation page", type: :system do
  def visit_invitation_for(**acceptance_methods)
    event = create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate)
    create(:card_grant_setting, event:)
    card_grant = create(:card_grant, :pending_invite, event:, amount_cents: 10_00, **acceptance_methods)
    card_grant.user.update!(phone_number_verified: true)

    allow_any_instance_of(SessionsHelper)
      .to receive(:find_current_session)
      .and_return(create(:user_session, user: card_grant.user))

    visit card_grant_path(card_grant)
    card_grant
  end

  context "when both acceptance methods are allowed" do
    let!(:card_grant) { visit_invitation_for(allow_stripe_card: true, allow_reimbursement_report: true) }

    it "keeps the virtual card button disabled until the Card Issuing Terms are agreed to" do
      expect(page).to have_button("Get a virtual card", disabled: true)

      check "terms"
      expect(page).to have_button("Get a virtual card", disabled: false)

      uncheck "terms"
      expect(page).to have_button("Get a virtual card", disabled: true)
    end

    it "opens a reimbursement once the grant's terms are agreed to, without the Card Issuing Terms" do
      # The browser blocks the submit and focuses the first unagreed term
      click_button "Open a reimbursement"
      expect(page).to have_field("purpose", focused: true)

      check "purpose"
      click_button "Open a reimbursement"
      expect(page).to have_field("policy", focused: true)

      check "policy"
      click_button "Open a reimbursement"

      # Returning the grant's balance to the event takes longer than Capybara's default wait
      expect(page).to have_text("Successfully opened a reimbursement report for your grant.", wait: 10)
      expect(card_grant.reload).to be_converted_to_reimbursement
      expect(page).to have_current_path(reimbursement_report_path(card_grant.reimbursement_report))
    end

    # Both buttons share one form, so a broken formaction would silently convert the grant instead
    it "sends the virtual card choice to card activation, not to a reimbursement" do
      expect_any_instance_of(CardGrant).to receive(:create_stripe_card)

      check "purpose"
      check "policy"
      check "terms"
      click_button "Get a virtual card"

      expect(page).to have_unchecked_field("terms")
      expect(page).to have_no_text("You must agree to the Card Issuing Terms")
      expect(card_grant.reload).to be_active
      expect(card_grant.reimbursement_report).to be_nil
    end
  end

  it "does not offer a virtual card when only reimbursements are allowed" do
    visit_invitation_for(allow_stripe_card: false, allow_reimbursement_report: true)

    expect(page).to have_button("Open a reimbursement")
    expect(page).to have_no_button("Get a virtual card")
    expect(page).to have_no_button("Start spending")
    expect(page).to have_no_field("terms")
  end

  it "does not offer a reimbursement when only virtual cards are allowed" do
    visit_invitation_for(allow_stripe_card: true, allow_reimbursement_report: false)

    expect(page).to have_button("Start spending")
    expect(page).to have_no_button("Open a reimbursement")
  end
end
