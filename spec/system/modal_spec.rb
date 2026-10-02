# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Modals", type: :system do
  include SystemSessionSupport

  let(:user) { create(:user, phone_number: "+18556254225") }
  let(:modal) { "#create_reimbursement_report" }

  def body_overflow = evaluate_script("document.body.style.overflow")

  before do
    create(:event, organizers: [user])
    sign_in(user)
    visit my_reimbursements_path
    click_on "Start report"
    expect(page).to have_css(modal, text: "Start a report")
  end

  it "locks page scrolling while open and restores it when closed with the close button" do
    expect(body_overflow).to eq("hidden")

    within(modal) { find(".modal__close").click }

    expect(page).to have_no_css(modal)
    expect(body_overflow).to eq("")
  end

  it "closes on Escape" do
    find("body").send_keys(:escape)

    expect(page).to have_no_css(modal)
  end

  it "closes when clicking the backdrop but not when clicking inside the modal" do
    within(modal) { find("h2", text: "Start a report").click }
    expect(evaluate_script("$.modal.isActive()")).to be(true)

    page.driver.browser.mouse.click(x: 5, y: 5) # top-left corner of the backdrop
    expect(page).to have_no_css(modal)
  end

  it "keeps form input when reopened" do
    within(modal) { fill_in "Report name", with: "Chicago Trip Expenses" }
    find("body").send_keys(:escape)
    expect(page).to have_no_css(modal)

    click_on "Start report"

    expect(page).to have_field("Report name", with: "Chicago Trip Expenses")
  end
end
