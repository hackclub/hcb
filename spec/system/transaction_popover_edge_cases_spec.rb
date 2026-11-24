# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Transaction popover edge cases", type: :system do
  let(:user) { create(:user, phone_number: "+18556254225") }
  let(:event) { create(:event, :with_positive_balance) }
  let(:hcb_code) { event.canonical_transactions.sole.local_hcb_code }
  let(:popover) { "#shared_popover" }
  let(:ledger_path) { event_transactions_path(event) }
  let(:popover_path) { event_transactions_path(event, popover: hcb_code_path(hcb_code)) }

  def press_escape = page.driver.browser.keyboard.type(:escape)
  def open_modals = evaluate_script("[...document.querySelectorAll('dialog.modal[open]')].map(dialog => dialog.id)")
  def expect_closed(selector) = expect(page).to have_no_css("#{selector}[open]", visible: :all)
  def settled(script) = evaluate_async_script("setTimeout(() => arguments[0](#{script}), 400)")

  def open_popover
    click_on "TEST DONATION"
    expect(page).to have_css("#{popover} #shared_popover_title", text: "for $1,000.00")
    expect(page).to have_css(popover, style: { translate: "none", opacity: "1" })
  end

  before do
    create(:organizer_position_invite, :accepted, event:, user:)
    sign_in(user)
    visit ledger_path
    click_on "No thanks, bring me straight to HCB"
  end

  it "comes back with Forward after closing with Back" do
    open_popover
    go_back
    expect_closed(popover)
    expect(page).to have_current_path(ledger_path)

    go_forward

    expect(page).to have_css("#{popover}[open] turbo-frame##{hcb_code.public_id}")
    expect(page).to have_current_path(popover_path)
  end

  it "leaves the URL and title as they were after opening and closing several times quickly" do
    title = page.title
    3.times do
      click_on "TEST DONATION"
      expect(page).to have_css("#{popover}[open]")
      press_escape
      expect_closed(popover)
    end

    expect(page).to have_current_path(ledger_path)
    expect(page).to have_title(title)
    expect(page).to have_no_css(".modal-backdrop", visible: :all)
  end

  it "closes cleanly when Escape is pressed before the transaction loads" do
    execute_script(<<~JS)
      document.addEventListener('turbo:before-fetch-request', event => {
        if (event.target.closest?.('#shared_popover')) {
          event.preventDefault()
          setTimeout(() => event.detail.resume(), 800)
        }
      })
    JS
    click_on "TEST DONATION"
    expect(page).to have_css("#{popover}[open] img[alt=Loading]")

    press_escape

    expect_closed(popover)
    expect(page).to have_current_path(ledger_path)
    expect(evaluate_async_script("setTimeout(() => arguments[0](document.querySelectorAll('#shared_popover turbo-frame').length), 1200)")).to eq(0)
  end

  # Its content changes underneath, so a modal from what it showed before would cover what it shows now
  it "closes modals opened from it when it loads something else" do
    open_popover
    html = ApplicationController.render(inline: <<~ERB)
      <%= modal "Related", id: "related" do %>
        <a href="#" id="relink">Show the transaction again</a>
      <% end %>
    ERB
    execute_script(<<~JS, html)
      document.querySelector('#shared_popover [data-popover-target=body]').insertAdjacentHTML('beforeend', arguments[0] + '<button type=button data-modal=related>Open related</button>')
      const relink = document.getElementById('relink')
      Object.assign(relink.dataset, document.querySelector('[data-popover-state-url]').dataset)
    JS
    within(popover) { click_on "Open related" }
    expect(page).to have_css("#related[open]", style: { scale: "none" })

    click_on "Show the transaction again"

    expect_closed("#related")
    expect(open_modals).to eq(["shared_popover"])
    expect(page).to have_css("#{popover} turbo-frame##{hcb_code.public_id}[complete]")
    press_escape
    expect_closed(popover)
    expect(page).to have_no_css(".modal-backdrop", visible: :all)
  end

  it "keeps working after its page is left and returned to with a modal open over it" do
    open_popover
    execute_script("Turbo.visit('/my/cards')")
    expect(page).to have_current_path("/my/cards")
    expect(page).to have_no_css(".modal-backdrop", visible: :all)

    execute_script("Turbo.visit(arguments[0])", ledger_path)
    expect(page).to have_css("tr", text: "TEST DONATION")
    expect(page).to have_no_css("html[data-turbo-preview]") # not Turbo's cached copy, which the real page replaces
    open_popover
    press_escape
    expect_closed(popover)
    expect(page).to have_current_path(ledger_path)
  end
end
