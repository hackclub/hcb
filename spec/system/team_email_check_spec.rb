# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Team email check on the invite form", type: :system do
  let(:manager) { create(:user) }
  let(:event) { create(:event) }

  before do
    create(:organizer_position, user: manager, event:, role: :manager, first_time: false)

    sign_in_browser(manager)
    visit new_event_organizer_position_invite_path(event)
  end

  def sign_in_browser(user)
    login = build(:login, user:)
    factors = login.available_factors.take(1)
    login.assign_attributes(factors.to_h { |factor| [:"authenticated_with_#{factor}", true] })
    login.save!

    user_session = create(:user_session, user:, verified: true, expiration_at: 1.day.from_now)
    login.update!(user_session:)

    jar = ActionDispatch::Request.new(Rails.application.env_config.deep_dup).cookie_jar
    jar.encrypted[:session_token] = user_session.session_token

    visit auth_users_path
    page.driver.set_cookie("session_token", Rack::Utils.escape(jar[:session_token]))
  end

  def type_email(value)
    field = find_field("organizer_position_invite[email]")
    field.value.length.times { field.send_keys(:backspace) } # real keystrokes so `input` fires
    field.send_keys(value) unless value.empty?
  end

  def expect_warning
    expect(page).to have_text("we discourage team emails")
  end

  def expect_no_warning
    expect(page).to have_no_text("we discourage team emails")
  end

  it "warns while a team email is typed" do
    expect_no_warning

    type_email("ben@hackclub.com")
    expect_no_warning

    %w[team webmaster marketing admin info about support sales hello].each do |word|
      type_email("#{word}@hackclub.com")
      expect_warning
    end

    type_email("orpheus.hello@hackclub.com")
    expect_warning

    type_email("TEAM@hackclub.com")
    expect_no_warning

    type_email("")
    expect_no_warning
  end

  it "sends the invite" do
    type_email("orpheus@hackclub.com")
    click_on "Send"

    expect(page).to have_text("Invite successfully sent to orpheus@hackclub.com")
    expect(event.organizer_position_invites.joins(:user).pluck("users.email")).to include("orpheus@hackclub.com")
  end
end
