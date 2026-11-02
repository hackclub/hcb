# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Login page", type: :system do
  it "opens the logo menu on right click and closes it on an outside click" do
    visit auth_users_path

    find("[data-menu-target=toggle]").right_click
    expect(page).to have_link("Brand guidelines")

    find_field("email").click
    expect(page).to have_no_link("Brand guidelines")
  end
end
