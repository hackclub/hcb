# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Spending allowance form", type: :system do
  let(:manager) { create(:user) }
  let(:member) { create(:user, full_name: "Orpheus Dino") }
  let(:event) { create(:event) }
  let(:organizer_position) { create(:organizer_position, user: member, event:, role: :member) }
  let!(:control) { OrganizerPosition::Spending::Control.create!(organizer_position:, active: true) }

  before do
    create(:organizer_position, user: manager, event:, role: :manager)
    control.allowances.create!(amount_cents: 123_45, memo: "Starting balance", authorized_by: manager)

    sign_in_browser(manager)
    visit event_organizer_position_spending_controls_path(event, organizer_position)
    # Opening a modal broadcasts `hcb:close-menus`, which a toggle-less menu on
    # this page throws on (unrelated to the form), so keep it from arriving
    page.execute_script("window.addEventListener('hcb:close-menus', e => e.stopImmediatePropagation(), true)")
    click_on "New"
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

  def type_amount(value)
    field = find_field("organizer_position_spending_control_allowance[amount]")
    # clear with real keystrokes so `input` fires (select-all shortcuts differ by OS)
    field.send_keys(:end, *Array.new(field.value.length, :backspace))
    field.send_keys(value) unless value.empty?
  end

  def expect_preview(balance)
    expect(page).to have_text("Orpheus Dino's spending balance will be #{balance}", exact: false)
  end

  def expect_no_preview
    expect(page).to have_no_text("spending balance will be")
  end

  it "previews the balance once an amount is typed" do
    expect_no_preview

    type_amount("10")
    expect_preview("$133.45")

    choose("Decrease allowance", allow_label_click: true)
    expect_preview("$113.45")

    type_amount("200")
    expect_preview("-$76.55")

    choose("Increase allowance", allow_label_click: true)
    expect_preview("$323.45")

    type_amount("1e2")
    expect_preview("$223.45")

    type_amount("0")
    expect_preview("$123.45")

    type_amount("-5")
    expect_no_preview

    type_amount("")
    expect_no_preview
  end

  it "waits for an amount before previewing a decrease" do
    choose("Decrease allowance", allow_label_click: true)
    expect_no_preview

    type_amount("23.45")
    expect_preview("$100.00")
  end

  it "creates the allowance" do
    choose("Decrease allowance", allow_label_click: true)
    type_amount("20")
    fill_in "organizer_position_spending_control_allowance[memo]", with: "Too many snacks"
    click_on "Create allowance"

    expect(page).to have_text("Too many snacks")
    expect(control.reload.balance_cents).to eq(103_45)
  end
end
