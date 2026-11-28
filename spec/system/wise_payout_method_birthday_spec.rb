# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Wise payout method date of birth", type: :system do
  let(:user) { create(:user) }
  let!(:payout_method) do
    user.personal_legal_entity.payout_methods.create!(default: true, details: create(:wise_transfer_payout_method_details))
  end

  before { sign_in(user) }

  def complete_details_form(method = payout_method)
    find("form[action='#{complete_details_payout_method_path(method)}']")
  end

  def segment(name)
    find("[data-segmented-data-input-target=#{name}]")
  end

  # Types into whichever segment has focus, the way a keyboard user would. Capybara's send_keys clicks the field first,
  # which opens the calendar over the form.
  def type(*keys)
    page.driver.browser.keyboard.type(*keys)
  end

  def tab_into(name)
    segment(name).execute_script("this.focus()")
  end

  def expect_focus_on(name)
    expect(page.active_element).to match_selector("[data-segmented-data-input-target=#{name}]")
  end

  def submitted_birthday
    find("input[type=hidden][name$='[recipient_birthday]']", visible: :hidden).value
  end

  # Saving renders the settings page again, which can outlast Capybara's default wait on a busy runner
  def expect_saved
    expect(page).to have_text("Payout method updated.", wait: 10)
  end

  def stored_birthday
    user.personal_legal_entity.reload.default_payout_method.details.recipient_birthday
  end

  context "when it's missing" do
    # Wise methods added before the date of birth was required don't have one
    before do
      payout_method.details.update!(recipient_birthday: nil)
      visit settings_payouts_path
    end

    it "moves to the next segment as each one fills and saves the date" do
      expect(find(".payout-methods__row")).to have_css(".badge", text: "Incomplete")

      within complete_details_form do
        tab_into(:month)
        type("01")
        expect_focus_on(:day)
        type("15")
        expect_focus_on(:year)
        type("1990")

        expect(submitted_birthday).to eq("01/15/1990")
        click_on "Save details"
      end

      expect_saved
      expect(find(".payout-methods__row")).to have_no_css(".badge", text: "Incomplete")
      expect(stored_birthday).to eq("01/15/1990")
    end

    it "ignores anything but digits" do
      within complete_details_form do
        tab_into(:month)
        type("ab")
        expect(segment(:month).value).to eq("")
        expect(submitted_birthday).to eq("")
      end
    end

    it "goes back a segment on Backspace in an empty one" do
      within complete_details_form do
        tab_into(:year)
        type(:backspace)
        expect_focus_on(:day)
        type(:backspace)
        expect_focus_on(:month)
      end
    end

    it "keeps focus on the segment you click" do
      within complete_details_form do
        segment(:day).click
        expect_focus_on(:day)
        segment(:year).click
        expect_focus_on(:year)
      end
    end

    it "fills in the day picked from the calendar" do
      within(complete_details_form) { find("[data-menu-target=toggle]").click }

      # The menu moves the calendar to the end of <body> while it's open
      calendar = find(".menu__content [data-controller=date-range-picker]")
      calendar.find("[data-role=prev-month]").click
      day = calendar.find("[data-role=weeks] button", exact_text: "15")
      picked = Date.parse(day["aria-label"])
      day.click

      expect(page).to have_no_css(".menu__content [data-controller=date-range-picker]")
      within complete_details_form do
        expect(segment(:month).value).to eq(picked.strftime("%m"))
        expect(segment(:day).value).to eq("15")
        expect(segment(:year).value).to eq(picked.year.to_s)
        click_on "Save details"
      end

      expect_saved
      expect(stored_birthday).to eq(picked.strftime("%m/%d/%Y"))
    end

    it "explains why an impossible date wasn't saved" do
      within complete_details_form do
        tab_into(:month)
        type("13", "45", "1990")
        click_on "Save details"
      end

      expect(page).to have_text("must be a valid date in MM/DD/YYYY format")
      expect(find(".payout-methods__row")).to have_css(".badge", text: "Incomplete")
      expect(stored_birthday).to be_nil
    end

    it "keeps each method's calendar to itself" do
      other = user.personal_legal_entity.payout_methods.create!(details: create(:wise_transfer_payout_method_details, currency: "EUR"))
      other.details.update!(recipient_birthday: nil)
      refresh

      within(complete_details_form) { find("[data-menu-target=toggle]").click }
      find(".menu__content [data-role=weeks] button", exact_text: "1", match: :first).click

      within(complete_details_form) { expect(segment(:day).value).to eq("01") }
      within(complete_details_form(other)) { expect(segment(:day).value).to eq("") }
    end
  end

  # KRW and ZAR collected the date with a native date field before it was required everywhere
  it "shows a date saved in ISO format and saves it back as MM/DD/YYYY" do
    payout_method.details.update!(recipient_birthday: "1990-01-15", account_holder: "Fiona Hackworth", bank_name: "Monzo", account_number: "GB29NWBK60161331926819")
    visit settings_payouts_path

    row = find(".payout-methods__row")
    row.click_on "Edit"
    within "#payout_method_form_#{payout_method.id}" do
      expect(segment(:month).value).to eq("01")
      expect(segment(:day).value).to eq("15")
      expect(segment(:year).value).to eq("1990")
    end
    row.click_on "Save"

    expect_saved
    expect(stored_birthday).to eq("01/15/1990")
  end
end
