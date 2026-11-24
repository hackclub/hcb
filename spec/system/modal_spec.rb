# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Modals", type: :system do
  let(:user) { create(:user, phone_number: "+18556254225") }
  let(:modal) { "#create_reimbursement_report" }

  # Sends Escape to the focused element without clicking anything first
  def press_escape = page.driver.browser.keyboard.type(:escape)

  def page_overflow = evaluate_script("getComputedStyle(document.documentElement).overflow")
  def open_modals = evaluate_script("[...document.querySelectorAll('dialog.modal[open]')].map(dialog => dialog.id)")

  # Clicks happen once the modal has finished animating in, where it'll stay
  def expect_open(selector) = expect(page).to have_css("#{selector}[open]", style: { opacity: "1" })
  # Not just faded out, but closed
  def expect_closed(selector) = expect(page).to have_no_css("#{selector}[open]", visible: :all)
  # What it's animating right now, as CSS transitions
  def transitions(selector) = evaluate_script("document.querySelector(arguments[0]).getAnimations().map(a => a.transitionProperty)", selector)

  before do
    create(:event, organizers: [user])
    sign_in(user)
    visit my_reimbursements_path
  end

  context "on a page" do
    before do
      click_on "Start report"
      expect_open(modal)
    end

    it "locks page scrolling while open and hands focus back to its trigger when closed" do
      expect(page_overflow).to eq("hidden")

      within(modal) { find(".modal__close").click }

      expect_closed(modal)
      expect(page_overflow).to eq("visible")
      expect(evaluate_script("document.activeElement.textContent")).to include("Start report")
    end

    # Opened with show(), not showModal(), so the page behind is kept out by hand
    it "keeps Tab inside the modal in both directions" do
      focus_in_modal = "!!document.activeElement.closest('#{modal}')"
      keyboard = page.driver.browser.keyboard

      12.times do
        keyboard.type(:tab)
        expect(evaluate_script(focus_in_modal)).to be(true)
      end
      12.times do
        keyboard.type([:shift, :tab])
        expect(evaluate_script(focus_in_modal)).to be(true)
      end
    end

    it "wraps Tab from its last control to its first, and back" do
      first, last = evaluate_script(<<~JS)
        (() => {
          const all = [...document.querySelectorAll('#{modal} a[href], #{modal} button, #{modal} input, #{modal} select, #{modal} textarea')]
            .filter(el => el.tabIndex >= 0 && !el.disabled && el.checkVisibility({ visibilityProperty: true }))
          all.at(-1).focus()
          return [all[0].outerHTML, all.at(-1).outerHTML]
        })()
      JS
      keyboard = page.driver.browser.keyboard

      keyboard.type(:tab)
      expect(evaluate_script("document.activeElement.outerHTML")).to eq(first)
      keyboard.type([:shift, :tab])
      expect(evaluate_script("document.activeElement.outerHTML")).to eq(last)
    end

    it "puts focus back in the modal when something behind it takes it" do
      execute_script("document.querySelector('a[href]:not(#{modal} a)').focus()")

      expect(evaluate_script("!!document.activeElement.closest('#{modal}')")).to be(true)
    end

    it "covers the page behind, so it can't be clicked, and tells screen readers it's modal" do
      expect(evaluate_script("document.elementFromPoint(5, 5).className")).to eq("modal-backdrop")
      expect(find(modal)["aria-modal"]).to eq("true")
    end

    it "closes on Escape" do
      press_escape

      expect_closed(modal)
    end

    # Closing a <dialog> takes it off screen at once, which Safari and Firefox can't animate
    it "animates out while still open before closing, from the close button and Escape" do
      within(modal) { find(".modal__close").click }
      expect(page).to have_css("#{modal}[open][data-closing]")
      expect(transitions(modal)).to include("opacity", "scale")
      expect_closed(modal)

      click_on "Start report"
      expect(transitions(modal)).to include("scale") # in, too
      expect(transitions(".modal-backdrop")).to include("opacity") # with its backdrop fading in
      expect_open(modal)
      press_escape
      expect(page).to have_css("#{modal}[open][data-closing]")
      expect(transitions(modal)).to include("opacity", "scale")
      expect(transitions(".modal-backdrop")).to include("opacity")
      expect_closed(modal)
      expect(page).to have_no_css(".modal-backdrop", visible: :all)
    end

    it "closes when clicking the backdrop but not when clicking inside the modal" do
      within(modal) { find("h2", text: "Start a report").click }
      expect(open_modals).to eq(["create_reimbursement_report"])

      page.driver.browser.mouse.click(x: 5, y: 5) # top-left corner of the backdrop
      expect_closed(modal)
    end

    it "stays open when a press inside it is released over the backdrop, as when selecting text" do
      heading = find("#{modal} h2", text: "Start a report")
      x, y = evaluate_script("(({ x, y }) => [x, y])(arguments[0].getBoundingClientRect())", heading)

      mouse = page.driver.browser.mouse
      mouse.move(x: x + 2, y: y + 2).down
      mouse.move(x: 5, y: 5).up

      expect(open_modals).to eq(["create_reimbursement_report"])
    end

    it "keeps form input when reopened" do
      within(modal) { fill_in "Report name", with: "Chicago Trip Expenses" }
      press_escape
      expect_closed(modal)

      click_on "Start report"

      expect(page).to have_field("Report name", with: "Chicago Trip Expenses")
    end
  end

  context "in tricky places" do
    # Rendered by the real helper, so this covers its markup as well as the JavaScript
    let(:fixture) do
      ApplicationController.render(inline: <<~ERB)
        <%= modal "Outer", id: "outer" do %>
          <button type="button" data-modal="inner">Open inner</button>
          <%= modal "Inner", id: "inner" do %><p>Inner body</p><% end %>
        <% end %>
        <div id="hidden_parent" hidden><%= modal "Hidden", id: "hidden_modal" do %><p>Hidden body</p><% end %></div>
        <turbo-frame id="fixture_frame"><%= modal "Framed", id: "framed" do %><p>Framed body</p><% end %></turbo-frame>
        <div style="pointer-events: none;"><%= modal "Styled", id: "styled" do %><button type="button" data-modal-close>Done</button><% end %></div>
        <button type="button" data-modal="outer">Open outer</button>
        <button type="button" data-modal="hidden_modal">Open hidden</button>
        <button type="button" data-modal="framed">Open framed</button>
        <button type="button" data-modal="styled">Open styled</button>
      ERB
    end

    before { execute_script("document.body.insertAdjacentHTML('beforeend', arguments[0])", fixture) }

    it "stacks a modal opened from inside another, and Escape closes only the top one" do
      click_on "Open outer"
      expect_open("#outer")
      click_on "Open inner"
      expect_open("#inner")
      expect(open_modals).to eq(%w[outer inner])

      press_escape

      expect_closed("#inner")
      expect(open_modals).to eq(["outer"])
      click_on "Open inner" # the outer modal is interactive again
      expect_open("#inner")
    end

    it "closes modals opened from inside one when it closes, so none is left blocking the page" do
      click_on "Open outer"
      expect_open("#outer")
      click_on "Open inner"
      expect_open("#inner")

      execute_script("document.getElementById('outer').close()")

      expect_closed("#inner")
      expect(open_modals).to be_empty
    end

    it "shows a modal rendered under a hidden ancestor, and puts it back when closed" do
      click_on "Open hidden"

      expect(page).to have_css("#hidden_modal", text: "Hidden body")

      press_escape
      expect_closed("#hidden_modal")
      expect(page).to have_css("#hidden_parent > #hidden_modal", visible: :hidden)
    end

    it "moves a modal out of its turbo-frame while open, so its links and forms navigate the page" do
      click_on "Open framed"
      expect_open("#framed")

      expect(evaluate_script("document.getElementById('framed').closest('turbo-frame')")).to be_nil

      press_escape
      expect(page).to have_css("#fixture_frame > #framed", visible: :hidden)
    end

    # Like a stretched-link table row, which turns off pointer events in its cells
    it "doesn't inherit styles from where it's rendered" do
      click_on "Open styled"
      expect_open("#styled")

      click_on "Done"

      expect_closed("#styled")
    end

    it "drops a lifted modal on close once the frame it came from has been replaced" do
      click_on "Open framed"
      expect_open("#framed")

      execute_script("document.getElementById('fixture_frame').replaceChildren()")
      press_escape

      expect(page).to have_no_css("#framed", visible: :all)
    end

    it "opens a modal rendered with open: true once, even though moving it reconnects its controllers" do
      html = ApplicationController.render(inline: %(<turbo-frame id="auto_frame"><%= modal "Auto", id: "auto", open: true do %><p>Auto body</p><% end %></turbo-frame>))
      execute_script("document.body.insertAdjacentHTML('beforeend', arguments[0])", html)
      expect_open("#auto")

      press_escape
      expect(page).to have_css("#auto_frame > #auto", visible: :hidden)

      expect(evaluate_async_script("setTimeout(() => arguments[0](document.getElementById('auto').open), 500)")).to be(false)
    end

    it "stays open when reopened while animating out" do
      click_on "Open outer"
      expect_open("#outer")

      execute_script(<<~JS)
        document.querySelector("#outer [data-modal-close]").click()
        document.querySelector("[data-modal=outer]").click()
      JS

      expect(evaluate_async_script("setTimeout(() => arguments[0](document.getElementById('outer').open), 500)")).to be(true)
      expect_open("#outer")
    end

    it "doesn't reopen a modal that opened itself when Back returns to its page" do
      html = ApplicationController.render(inline: %(<%= modal "Once", id: "once", open: true do %><a href="/my/cards">Go to cards</a><% end %>))
      execute_script("document.body.insertAdjacentHTML('beforeend', arguments[0])", html)
      expect_open("#once")
      click_on "Go to cards"
      expect(page).to have_current_path("/my/cards")
      # Back while its frames load cancels their requests, which Turbo leaves as an
      # unhandled AbortError that fails the spec
      expect(page).to have_no_css("turbo-frame[busy]", visible: :all)

      go_back

      expect(page).to have_current_path(my_reimbursements_path)
      expect(page).to have_no_css("#once", visible: :all)
    end

    # `close` fires a task later, after the reopen, and mustn't undo it
    it "stays open and on top when reopened before its close event lands" do
      click_on "Open outer"
      expect_open("#outer")
      click_on "Open inner"
      expect_open("#inner")

      execute_script("document.getElementById('inner').close(); document.querySelector('[data-modal=inner]').click()")

      expect(evaluate_async_script("setTimeout(() => arguments[0](document.getElementById('inner').open), 300)")).to be(true)
      press_escape
      expect_closed("#inner")
      expect(open_modals).to eq(["outer"])
    end

    it "opens from a Turbo Stream" do
      stream = ApplicationController.render(inline: %(<%= turbo_stream.open_modal("outer") %>))
      execute_script("Turbo.renderStreamMessage(arguments[0])", stream)

      expect_open("#outer")
    end

    it "lets Escape dismiss a SweetAlert over a modal and leave the modal open" do
      click_on "Open outer"
      expect_open("#outer")
      execute_script("swal('Saved!')")
      expect(page).to have_css(".swal-overlay--show-modal")

      press_escape

      expect(page).to have_no_css(".swal-overlay--show-modal")
      expect(evaluate_async_script("setTimeout(() => arguments[0](document.getElementById('outer').open), 500)")).to be(true)
    end

    it "hands focus back to the button that asked for confirmation inside a modal" do
      html = ApplicationController.render(inline: %(<%= modal "Confirming", id: "confirming" do %><%= button_to "Delete it", "/", data: { turbo_confirm: "Sure?" } %><% end %>))
      stream = ApplicationController.render(inline: %(<%= turbo_stream.open_modal("confirming") %>))
      execute_script("document.body.insertAdjacentHTML('beforeend', arguments[0]); Turbo.renderStreamMessage(arguments[1])", html, stream)
      expect_open("#confirming")

      click_on "Delete it"
      click_on "Cancel"

      expect(page).to have_button("Delete it", focused: true)
    end

    # It fades out in the modal's layer, which mustn't take the overlay back from the new alert
    it "shows an alert opened while the last one inside a modal is still fading out" do
      click_on "Open outer"
      expect_open("#outer")
      execute_script("swal('Saved!').then(() => swal('Again!'))")
      click_on "OK"

      expect(page).to have_css(".swal-overlay--show-modal", text: "Again!")
      click_on "OK"
      expect(open_modals).to eq(["outer"])
    end

    it "keeps a SweetAlert opened inside a modal clickable" do
      click_on "Open outer"
      expect_open("#outer")

      execute_script("swal('Saved!')")
      click_on "OK"

      expect(page).to have_no_css(".swal-overlay--show-modal")
      expect(open_modals).to eq(["outer"])
    end
  end
end
