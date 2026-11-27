# frozen_string_literal: true

require "rails_helper"

# Escape closes whatever's on top, one press at a time (app/javascript/layers.js)
RSpec.describe "Escape", type: :system do
  let(:user) { create(:user, phone_number: "+18556254225") }
  let!(:event) { create(:event, organizers: [user]) }

  def press_escape = page.driver.browser.keyboard.type(:escape)

  before { sign_in(user) }

  it "still reaches the page after leaving one with a modal open" do
    visit my_reimbursements_path
    html = ApplicationController.render(inline: %(<%= modal "Away", id: "away" do %><a href="/my/cards">Go to cards</a><% end %><button type="button" data-modal="away">Open away</button>))
    execute_script("document.body.insertAdjacentHTML('beforeend', arguments[0])", html)
    click_on "Open away"
    expect(page).to have_css("#away[open]", style: { scale: "none" })

    click_on "Go to cards"
    expect(page).to have_current_path("/my/cards")
    # Escape clears a search field, unless something claims it first
    execute_script("document.body.insertAdjacentHTML('beforeend', '<input type=search id=search value=lunch>'); document.getElementById('search').focus()")
    press_escape

    expect(evaluate_script("document.getElementById('search').value")).to eq("")
  end

  it "closes the command bar before a modal beneath it" do
    visit my_reimbursements_path
    html = ApplicationController.render(inline: %(<%= modal "Beneath", id: "beneath" do %>Under the command bar<% end %><button type="button" data-modal="beneath">Open beneath</button>))
    execute_script("document.body.insertAdjacentHTML('beforeend', arguments[0])", html)
    click_on "Open beneath"
    expect(page).to have_css("#beneath[open]", style: { scale: "none" })

    # Its triggers are under the backdrop, as they would be for ⌘K
    execute_script("document.querySelector('[data-behavior~=command_bar_trigger]').click()")
    expect(page).to have_css("[data-above-modals] [role=combobox]")
    expect(evaluate_script("!!document.activeElement.closest('[data-above-modals]')")).to be(true)

    press_escape
    expect(page).to have_no_css("[data-above-modals]")
    # Not on its way out either: closing marks it at once and keeps `open` while it animates
    expect(page).to have_css("#beneath[open]:not([data-closing])")

    press_escape
    expect(page).to have_no_css("#beneath[open]", visible: :all)
  end

  it "closes a modal opened while editing an expense before cancelling the edit" do
    report = create(:reimbursement_report, user:, event:)
    expense = create(:reimbursement_expense, report:, memo: "Lunch")
    visit reimbursement_report_path(report)
    memo = find("#reimbursement_expense_memo_#{expense.id}")
    memo.double_click
    memo.fill_in(with: "Dinner")

    click_on "Select from Receipt Bin"
    expect(page).to have_css("dialog[id^=link_receipt_][open]", style: { scale: "none" })

    press_escape
    expect(page).to have_no_css("dialog[open]", visible: :all)
    expect(memo.value).to eq("Dinner")

    press_escape
    expect(memo.value).to eq("Lunch")
  end

  it "closes a menu in the mobile sidebar before the sidebar" do
    page.driver.resize(390, 844)
    visit my_reimbursements_path
    toggle = find("[aria-label='Open navigation']")
    toggle.click
    find(".user-menu-trigger", match: :first).click
    expect(page).to have_link("Sign out")

    press_escape
    expect(page).to have_no_link("Sign out")
    expect(toggle["aria-expanded"]).to eq("true")

    press_escape
    expect(page).to have_css("[aria-label='Open navigation'][aria-expanded=false]")
  end
end
