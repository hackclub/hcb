# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sub-organization scoped tag picker", type: :system do
  let(:manager) { create(:user) }
  let(:event) { create(:event) }

  before do
    event.config.update!(subevent_plan: Event::Plan::Standard.name)
    create(:organizer_position, user: manager, event:, role: :manager, first_time: false)
    event.subevent_scoped_tags.create!(name: "Robotics")
    event.subevent_scoped_tags.create!(name: "Art")

    sign_in_browser(manager)
    visit event_new_sub_organization_path(event)
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

  def search(query)
    field = find_field("scoped_tag_name")
    field.click
    field.send_keys(query)
  end

  def pick(name)
    find_field("scoped_tag_name").click
    within("#scoped_tag_menu") { click_button name }
  end

  def selected_tags
    find("[data-scoped-tag-picker-target='tags']")
  end

  def selected_tag_ids
    all("input[name='scoped_tags[]']", visible: false).map(&:value)
  end

  it "picks and removes tags" do
    pick("Robotics")
    pick("Art")
    pick("Robotics")

    expect(selected_tags).to have_text("Robotics")
    expect(selected_tags).to have_text("Art")
    expect(selected_tag_ids).to match_array(event.subevent_scoped_tags.pluck(:id).map(&:to_s))

    within(selected_tags) { find(".badge", text: "Robotics").find("button").click }

    expect(selected_tags).to have_no_text("Robotics")
    expect(selected_tag_ids).to eq([event.subevent_scoped_tags.find_by(name: "Art").id.to_s])
  end

  it "clears the query once a tag is picked" do
    search("Rob")
    within("#scoped_tag_menu") { click_button "Robotics" }

    expect(find_field("scoped_tag_name").value).to eq("")
    find_field("scoped_tag_name").click
    within("#scoped_tag_menu") do
      expect(page).to have_button("Art")
      expect(page).to have_no_link("Create tag")
    end
  end

  it "creates a tag from the query" do
    find_field("scoped_tag_name").click
    within("#scoped_tag_menu") { expect(page).to have_no_link("Create tag") }

    search("Space & Rockets")
    within("#scoped_tag_menu") { click_link "Create tag \"Space & Rockets\"" }

    expect(page).to have_button("Space & Rockets", visible: :all)
    expect(event.subevent_scoped_tags.pluck(:name)).to include("Space & Rockets")
  end
end
