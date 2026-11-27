# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Card grant email", type: :system do
  let(:event) { create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate) }
  let(:card_grant) { create(:card_grant, event:) }

  def visit_grant_as(role)
    user = create(:user)
    create(:organizer_position, user:, event:, role:, first_time: false)
    sign_in(user)
    visit card_grant_path(card_grant)
  end

  def cancel_grant
    card_grant.update_columns(status: :canceled)
    card_grant.stripe_card.update_columns(stripe_status: "canceled")
  end

  it "shows a member the address the grant was sent to, not the grantee's current one" do
    card_grant.user.update_columns(email: "changed@example.com")
    visit_grant_as(:member)

    expect(page).to have_text(card_grant.email)
    expect(page).to have_no_text("changed@example.com")
  end

  it "shows a member the email on a canceled grant" do
    cancel_grant
    visit_grant_as(:member)

    expect(page).to have_text("This grant has been canceled")
    expect(page).to have_text(card_grant.email)
  end

  it "shows a member the email on a grant canceled before the card was activated" do
    card_grant.update!(stripe_card: nil)
    card_grant.update_columns(status: :canceled)
    visit_grant_as(:member)

    expect(page).to have_text("canceled before the card was activated")
    expect(page).to have_text(card_grant.email)
  end

  it "shows a member the email on an expired grant" do
    card_grant.update_columns(status: :expired)
    card_grant.stripe_card.update_columns(stripe_status: "canceled")
    visit_grant_as(:member)

    expect(page).to have_text("This grant expired on")
    expect(page).to have_text(card_grant.email)
  end

  it "hides the email from a reader" do
    visit_grant_as(:reader)

    expect(page).to have_text("Spending controls")
    expect(page).to have_no_text(card_grant.email)
  end

  it "hides the email from a reader once the grant is canceled" do
    cancel_grant
    visit_grant_as(:reader)

    expect(page).to have_text("This grant has been canceled")
    expect(page).to have_no_text(card_grant.email)
  end
end
