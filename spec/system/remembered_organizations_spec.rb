# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Remembered organizations", type: :system do
  let(:user) { create(:user) }
  let(:event) do
    create(:event, organizers: [user], is_public: true).tap do |event|
      # Skip the first-visit welcome overlay, which covers the user menu
      event.organizer_positions.update_all(first_time: false)
    end
  end

  # Re-checks expiry on every request, like the real lookup, so expiring or
  # signing out of the session takes effect on the next page.
  def sign_in_as(user)
    user_session = create(:user_session, user:, expiration_at: 1.hour.from_now)
    allow_any_instance_of(SessionsHelper).to receive(:find_current_session) do
      User::Session.not_expired.find_by(id: user_session.id)
    end
    user_session
  end

  def remembered_organizations
    page.evaluate_script("JSON.parse(localStorage.getItem('hcb:remembered-organizations'))")
  end

  it "prompts the user to sign in after their session expires" do
    user_session = sign_in_as(user)
    visit event_path(event)
    expect(page).to have_css("[data-controller~='remembered-organizations']")
    expect(remembered_organizations).to eq([event.public_id])

    user_session.update!(expiration_at: 1.minute.ago)
    visit event_path(event)

    expect(page).to have_css(".user-menu-trigger--nudge")
    expect(page).to have_text("You’ve been signed out")
    within("#signed_out_organizer") do
      expect(page).to have_text("You’re signed out")
      expect(page).to have_text("You’re seeing #{event.name} the way the public does.")
      return_to = Rack::Utils.parse_query(URI(find_link("Sign in")[:href]).query)["return_to"]
      expect(URI(return_to).path).to eq(event_path(event))
    end
  end

  it "doesn't reopen the modal once it's closed in the same tab" do
    user_session = sign_in_as(user)
    visit event_path(event)
    expect(page).to have_css("[data-controller~='remembered-organizations']")

    user_session.update!(expiration_at: 1.minute.ago)
    visit event_path(event)
    within("#signed_out_organizer") { click_link "Keep browsing" }

    expect(page).to have_no_css("#signed_out_organizer", visible: true)

    visit event_path(event)

    expect(page).to have_css(".user-menu-trigger--nudge")
    expect(page).to have_no_css("#signed_out_organizer", visible: true)
  end

  it "does not nudge on organizations the user doesn't manage" do
    other_event = create(:event, is_public: true)
    user_session = sign_in_as(user)
    visit event_path(event)
    expect(page).to have_css("[data-controller~='remembered-organizations']")

    user_session.update!(expiration_at: 1.minute.ago)
    visit event_path(other_event)

    expect(page).to have_link("Sign in")
    expect(page).to have_no_css(".user-menu-trigger--nudge")
    expect(page).to have_no_text("You’ve been signed out")
    expect(page).to have_no_css("#signed_out_organizer", visible: true)
  end

  it "forgets organizations after an explicit sign out" do
    sign_in_as(user)
    visit event_path(event)
    expect(page).to have_css("[data-controller~='remembered-organizations']")

    find(".user-menu-trigger").click
    click_link "Sign out"
    expect(page).to have_current_path(auth_users_path, ignore_query: true)

    visit event_path(event)

    expect(page).to have_link("Sign in")
    expect(page).to have_no_css(".user-menu-trigger--nudge")
    expect(page).to have_no_css("#signed_out_organizer", visible: true)
    expect(remembered_organizations).to be_nil
  end
end
