# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Command bar", type: :system do
  include SystemSessionSupport

  let(:user) { create(:user, phone_number: "+18556254225") }
  let!(:own_event) { create(:event, name: "Robotics Club North", organizers: [user]) }
  let!(:other_event) { create(:event, name: "Robotics Club South") }

  before do
    sign_in(user)
    visit root_path
    click_on "Jump to..."
  end

  def search(query)
    find("[role=combobox]").set(query)
  end

  it "opens one of the user's organizations" do
    search(own_event.name)
    find("[role=option]", text: own_event.name).click
    find("[role=option]", text: "Home").click

    expect(page).to have_current_path("/#{own_event.slug}")
  end

  it "does not list organizations the user is not a member of" do
    search("Robotics Club")

    expect(page).to have_css("[role=listbox]", text: own_event.name)
    expect(page).to have_no_css("[role=listbox]", text: other_event.name)
  end
end
