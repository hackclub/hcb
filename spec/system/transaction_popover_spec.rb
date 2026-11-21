# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Transaction popovers", type: :system do
  let(:user) { create(:user, phone_number: "+18556254225") }
  let(:event) { create(:event, :with_positive_balance) }
  let(:hcb_code) { event.canonical_transactions.sole.local_hcb_code }
  let(:popover) { "#shared_popover" }

  def press_escape = page.driver.browser.keyboard.type(:escape)
  def expect_closed(selector) = expect(page).to have_no_css("#{selector}[open]", visible: :all)
  def transitions = evaluate_script("document.querySelector('#shared_popover').getAnimations().map(a => a.transitionProperty)")
  def open_modals = evaluate_script("[...document.querySelectorAll('dialog.modal[open]')].map(dialog => dialog.id)")

  def open_popover
    click_on "TEST DONATION"
    expect(page).to have_css("#{popover} #shared_popover_title", text: "for $1,000.00")
    # Wait for the slide-in to finish so clicks land where the close button ends up
    expect(page).to have_css(popover, style: { translate: "none", opacity: "1" })
  end

  before do
    create(:organizer_position_invite, :accepted, event:, user:)

    sign_in(user)
    visit event_transactions_path(event)
    click_on "No thanks, bring me straight to HCB"
  end

  it "loads the transaction into the popover and shows its URL" do
    open_popover

    expect(page).to have_css("#{popover} turbo-frame##{hcb_code.public_id}[complete]")
    expect(page).to have_current_path(event_transactions_path(event, popover: hcb_code_path(hcb_code)))
  end

  it "restores the ledger URL and title when closed" do
    ledger_title = page.title
    open_popover

    find("#{popover} .modal__close").click

    expect_closed(popover)
    expect(page).to have_current_path(event_transactions_path(event))
    expect(page).to have_title(ledger_title)
  end

  it "slides in, and out with the transaction still showing" do
    click_on "TEST DONATION"
    expect(transitions).to include("translate")
    expect(page).to have_css(popover, style: { translate: "none", opacity: "1" })

    find("#{popover} .modal__close").click

    expect(page).to have_css("#{popover}[data-closing] turbo-frame##{hcb_code.public_id}")
    expect(transitions).to include("translate")
    expect_closed(popover)
    expect(page).to have_no_css("#{popover} turbo-frame", visible: :all)
  end

  it "lets the transaction it showed be garbage collected once closed" do
    execute_script(<<~JS)
      window.loadedFrames = []
      document.addEventListener('turbo:frame-load', ({ target }) => window.loadedFrames.push(new WeakRef(target)))
    JS
    open_popover
    # Waited on in JS: a Capybara node handle would itself keep the frame alive
    Timeout.timeout(10) { sleep 0.05 until evaluate_script("!!document.querySelector('#shared_popover turbo-frame[complete]')") }
    press_escape
    expect_closed(popover)

    page.driver.browser.page.command("HeapProfiler.collectGarbage")
    expect(evaluate_script("window.loadedFrames.length")).to be_positive
    expect(evaluate_script("window.loadedFrames.filter(frame => frame.deref()).length")).to eq(0)
  end

  # Each one used to bind another set of tooltip handlers, slowing every later click and hover
  it "adds no page-wide handlers each time a transaction loads" do
    handlers = "(events => Object.values(events ?? {}).reduce((sum, list) => sum + list.length, 0))(jQuery._data(document, 'events'))"
    open_popover
    expect(page).to have_css("#{popover} turbo-frame[complete]")
    press_escape
    expect_closed(popover)
    before = evaluate_script(handlers)

    2.times do
      open_popover
      expect(page).to have_css("#{popover} turbo-frame[complete]")
      press_escape
      expect_closed(popover)
    end

    expect(evaluate_script(handlers)).to eq(before)
  end

  it "opens a receipt in its own modal over the popover, which Escape closes first" do
    Receipt.create!(receiptable: hcb_code.ledger_item, user:, upload_method: :transaction_popover,
                    file: { io: file_fixture("receipt.png").open, filename: "receipt.png" })
    open_popover

    within(popover) { find("img.receipt--image").click }

    receipt_modal = "dialog[id^=preview_receipt_][open]"
    expect(page).to have_css(receipt_modal, style: { scale: "none" })
    expect(open_modals.length).to eq(2)
    expect(open_modals.first).to eq("shared_popover")

    press_escape
    expect(page).to have_no_css(receipt_modal, visible: :all)
    expect(open_modals).to eq(["shared_popover"])
    press_escape
    expect_closed(popover)
  end

  it "opens a comment's edit history from its edited link" do
    comment = hcb_code.comments.create!(user:, content: "Was for snacks", has_untracked_edit: true)
    open_popover

    within(popover) { click_on "edited" }

    expect(page).to have_css("#comment-modal-#{comment.hashid}[open]")
  end

  it "reopens when Back returns to the ledger after leaving from inside it" do
    open_popover
    execute_script("Turbo.visit('/my/cards')")
    expect(page).to have_current_path("/my/cards")

    go_back

    expect(page).to have_current_path(event_transactions_path(event, popover: hcb_code_path(hcb_code)))
    expect(page).to have_css("h1", text: "Transactions")
    expect(page).to have_css("#{popover}[open] turbo-frame##{hcb_code.public_id}")
  end

  # Turbo would re-render the whole ledger for it, or snapshot it and close every modal at once
  it "animates out on Back, without Turbo touching the page" do
    open_popover
    execute_script("document.body.dataset.untouched = true")

    go_back

    expect(page).to have_css("#{popover}[open][data-closing]")
    expect_closed(popover)
    expect(page).to have_css("body[data-untouched]")
  end

  it "takes one Back to leave the ledger, which doesn't add a history entry when it loads" do
    visit my_reimbursements_path
    execute_script("Turbo.visit(arguments[0])", event_transactions_path(event))
    expect(page).to have_css("tr", text: "TEST DONATION")

    go_back

    expect(page).to have_current_path(my_reimbursements_path)
  end

  it "closes on browser back" do
    open_popover

    go_back

    expect_closed(popover)
    expect(page).to have_current_path(event_transactions_path(event))
  end

  it "reopens on browser back after being closed" do
    open_popover
    find("#{popover} .modal__close").click
    expect_closed(popover)

    go_back

    expect(page).to have_css(popover)
    expect(page).to have_current_path(event_transactions_path(event, popover: hcb_code_path(hcb_code)))
  end

  context "with a tag" do
    let!(:tag) { Tag.create!(event:, label: "Snacks", emoji: "🍕", color: "green") }

    # The menu would be inert on <body>, behind the popover, and so would the confirmation
    it "deletes it through the menu and confirmation inside the popover" do
      open_popover
      within(popover) { click_on "+ Add tag" }

      find("button[title='Delete this tag']").click
      click_on "Confirm"

      expect(page).to have_no_css(".swal-overlay--show-modal")
      expect { tag.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    # It's rendered on the page, not in the popover, but was opened from it
    it "closes the create tag modal along with the popover it was opened from" do
      open_popover
      within(popover) { click_on "+ Add tag" }
      click_on "Create tag"
      expect(page).to have_css("#create_tag[open]", style: { scale: "none" })

      go_back

      expect_closed("#create_tag")
      expect_closed(popover)
    end

    it "keeps a modal working after a morph refresh while it's open" do
      open_create_tag = lambda do
        find("tr", text: "TEST DONATION").hover
        find(".add-tag-badge").click
        click_on "Create tag"
        expect(page).to have_css("#create_tag[open]", style: { scale: "none" })
      end
      open_create_tag.call

      execute_script("Turbo.session.refresh(location.href)")
      expect(page).to have_no_css("#create_tag[open]", visible: :all, wait: 10)

      open_create_tag.call
    end

    it "opens the create tag modal from its menu on top of the popover" do
      open_popover
      within(popover) { click_on "+ Add tag" }
      click_on "Create tag"

      expect(page).to have_css("#create_tag[open]")
      fill_in "Tag name", with: "Travel"
      expect(open_modals).to contain_exactly("shared_popover", "create_tag")

      press_escape
      expect_closed("#create_tag")
      expect(open_modals).to eq(["shared_popover"])
    end
  end

  context "with a modal over it and a menu open in that" do
    let(:menu_item) { "Option one" }

    before do
      open_popover
      html = ApplicationController.render(inline: <<~ERB)
        <%= modal "Layered", id: "layered" do %>
          <div data-controller="menu">
            <button type="button" data-menu-target="toggle" data-action="menu#toggle">Options</button>
            <div data-menu-target="content" class="menu__content"><span>#{menu_item}</span></div>
          </div>
        <% end %>
      ERB
      stream = ApplicationController.render(inline: %(<%= turbo_stream.open_modal("layered") %>))
      execute_script("document.body.insertAdjacentHTML('beforeend', arguments[0]); Turbo.renderStreamMessage(arguments[1])", html, stream)
      expect(page).to have_css("#layered[open]", style: { opacity: "1" })
      click_on "Options"
      expect(page).to have_text(menu_item)
    end

    it "closes the menu, then the modal, then the popover, one per Escape" do
      press_escape
      expect(page).to have_no_text(menu_item)
      expect(open_modals).to contain_exactly("shared_popover", "layered")

      press_escape
      expect_closed("#layered")
      expect(open_modals).to eq(["shared_popover"])

      press_escape
      expect_closed(popover)
      expect(open_modals).to be_empty
    end

    # Each press moves on, rather than landing on a modal that's still animating out
    it "closes all three when Escape is pressed three times quickly" do
      3.times { press_escape }

      expect(page).to have_no_text(menu_item)
      expect_closed("#layered")
      expect_closed(popover)
    end
  end

  it "cancels renaming the transaction on Escape without closing the popover" do
    open_popover
    within(popover) { find("[aria-label='Rename']").click }
    rename = find("#{popover} input[name='hcb_code[memo]']")

    rename.send_keys(:escape)

    expect(page).to have_no_css("#{popover} input[name='hcb_code[memo]']")
    expect(open_modals).to eq(["shared_popover"])
  end

  # Morphing drops `open`, which alone would leave it hidden but blocking the page
  it "reopens with fresh content after a morph refresh, as a reload would" do
    open_popover
    execute_script("document.querySelector('#{popover} turbo-frame').dataset.stale = true")

    execute_script("Turbo.session.refresh(location.href)")

    # The refresh reloads the page and its frames before the popover's own
    expect(page).to have_css("#{popover} turbo-frame##{hcb_code.public_id}[complete]:not([data-stale])", wait: 10)
    expect(open_modals).to eq(["shared_popover"])
    expect(page).to have_current_path(event_transactions_path(event, popover: hcb_code_path(hcb_code)))

    # The close the morph caused lands after the reopen, and mustn't undo it
    press_escape
    expect_closed(popover)
  end

  it "ignores a ?popover= that matches no link, however it's written" do
    visit event_transactions_path(event, popover: %q{"]) , [x='})

    expect(page).to have_css("h1", text: "Transactions")
    expect_closed(popover)
  end
end
