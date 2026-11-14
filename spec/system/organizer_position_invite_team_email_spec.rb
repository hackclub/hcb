# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Team email warning on the invite form", type: :system do
  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let(:warning) { "we discourage shared emails on HCB" }

  before do
    create(:organizer_position, user:, event:, role: :manager)

    session = create(:user_session, user:, expiration_at: 1.day.from_now, verified: true)
    allow_any_instance_of(ApplicationController).to receive(:find_current_session).and_return(session)
  end

  it "follows the address keystroke by keystroke, without waiting for the field to lose focus" do
    visit new_event_organizer_position_invite_path(event)
    expect(page).to have_no_text(warning)

    email = find_field("organizer_position_invite[email]")

    email.fill_in(with: "hell")
    expect(page).to have_no_text(warning)

    email.send_keys("o")
    expect(page).to have_text(warning)

    email.send_keys(:backspace)
    expect(page).to have_no_text(warning)

    email.fill_in(with: "support@hackclub.com")
    expect(page).to have_text(warning)

    email.fill_in(with: "ben@hackclub.com")
    expect(page).to have_no_text(warning)
  end
end
