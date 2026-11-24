# frozen_string_literal: true

require "rails_helper"

# The corners of app/javascript/modal.js and app/javascript/layers.js that
# spec/system/modal_spec.rb doesn't reach: modals removed or replaced while
# open, several open at once, odd triggers, menus inside modals, focus and
# scrolling.
RSpec.describe "Modal edge cases", type: :system do
  let(:user) { create(:user, phone_number: "+18556254225") }

  def press_escape = page.driver.browser.keyboard.type(:escape)
  def press_tab = page.driver.browser.keyboard.type(:tab)
  def open_modals = evaluate_script("[...document.querySelectorAll('dialog.modal[open]')].map(dialog => dialog.id)")
  def backdrops = evaluate_script("document.querySelectorAll('.modal-backdrop').length")
  def page_overflow = evaluate_script("getComputedStyle(document.documentElement).overflow")
  def focused_id = evaluate_script("document.activeElement?.id")
  def expect_open(selector) = expect(page).to have_css("#{selector}[open]", style: { opacity: "1", scale: "none" })
  def expect_closed(selector) = expect(page).to have_no_css("#{selector}[open]", visible: :all)
  def run_stream(erb) = execute_script("Turbo.renderStreamMessage(arguments[0])", ApplicationController.render(inline: erb))
  def insert(erb) = execute_script("document.body.insertAdjacentHTML('beforeend', arguments[0])", ApplicationController.render(inline: erb))
  # Whatever's at a point on the page: the backdrop while a modal is open
  def element_at(x, y) = evaluate_script("document.elementFromPoint(#{x}, #{y})?.className")
  # Settled, after any animation and the `close` event a task later
  def settled(script) = evaluate_async_script("setTimeout(() => arguments[0](#{script}), 400)")

  before do
    create(:event, organizers: [user])
    sign_in(user)
    visit my_reimbursements_path
    expect(page).to have_css("[data-modal=create_reimbursement_report]", text: "Start report")
  end

  context "removed or replaced while open" do
    before do
      insert(<<~ERB)
        <div id="holder"><%= modal "Doomed", id: "doomed" do %><button type="button" id="doomed_button">Inside</button><% end %></div>
        <button type="button" id="doomed_trigger" data-modal="doomed">Open doomed</button>
      ERB
      click_on "Open doomed"
      expect_open("#doomed")
    end

    it "leaves nothing blocking the page when a Turbo Stream removes it" do
      run_stream(%(<%= turbo_stream.remove("doomed") %>))

      expect(page).to have_no_css("#doomed", visible: :all)
      expect(page).to have_no_css(".modal-backdrop", visible: :all)
      expect(page_overflow).to eq("visible")
      click_on "Start report" # the page behind takes clicks again
      expect_open("#create_reimbursement_report")
    end

    it "leaves the fresh copy closed and nothing blocking the page when a Turbo Stream replaces it" do
      run_stream(%(<%= turbo_stream.replace("doomed") do %><%= modal "Fresh", id: "doomed" do %><p>Fresh body</p><% end %><% end %>))

      expect(page).to have_css("#doomed", visible: :hidden, text: "Fresh body")
      expect(page).to have_no_css(".modal-backdrop", visible: :all)
      expect(open_modals).to be_empty

      click_on "Open doomed"
      expect_open("#doomed")
      expect(page).to have_text("Fresh body")
      press_escape
      expect_closed("#doomed")
      expect(backdrops).to eq(0)
    end

    it "lets focus and Escape reach the page again once it's gone" do
      execute_script("document.getElementById('doomed').remove()")
      expect(page).to have_no_css(".modal-backdrop", visible: :all)

      execute_script("document.body.insertAdjacentHTML('beforeend', '<input type=search id=after value=lunch>'); document.getElementById('after').focus()")
      expect(focused_id).to eq("after")
      press_escape
      expect(evaluate_script("document.getElementById('after').value")).to eq("")
    end

    it "keeps the one beneath working when the top one is removed" do
      insert(%(<%= modal "Top", id: "top" do %><button type="button">Top button</button><% end %>))
      execute_script("document.querySelector('#doomed').insertAdjacentHTML('beforeend', '<button type=button data-modal=top id=top_trigger>Open top</button>')")
      click_on "Open top"
      expect_open("#top")

      execute_script("document.getElementById('top').remove()")

      expect(backdrops).to eq(1)
      expect(element_at(5, 5)).to eq("modal-backdrop")
      click_on "Inside" # the one beneath is on top again
      press_escape
      expect_closed("#doomed")
      expect(backdrops).to eq(0)
    end
  end

  context "with several open" do
    before do
      insert(<<~ERB)
        <%= modal "First", id: "first" do %><button type="button" data-modal="second">Open second</button><% end %>
        <%= modal "Second", id: "second" do %><button type="button" data-modal="third">Open third</button><% end %>
        <%= modal "Third", id: "third" do %><button type="button" id="third_button">Third button</button><% end %>
        <%= modal "Unrelated", id: "unrelated" do %><button type="button" id="unrelated_button">Unrelated button</button><% end %>
        <button type="button" data-modal="first">Open first</button>
      ERB
      click_on "Open first"
      expect_open("#first")
      click_on "Open second"
      expect_open("#second")
      click_on "Open third"
      expect_open("#third")
    end

    it "closes every one opened from the one that closes, however deep, with its backdrop" do
      # Covered by the ones above, so clicked from code
      execute_script("document.querySelector('#first [data-modal-close]').click()")

      expect_closed("#first")
      expect_closed("#second")
      expect_closed("#third")
      expect(page).to have_no_css(".modal-backdrop", visible: :all)
      expect(page_overflow).to eq("visible")
    end

    it "closes them from the top down, one per Escape, handing focus back to each trigger" do
      press_escape
      expect_closed("#third")
      expect(open_modals).to eq(%w[first second])
      expect(evaluate_script("document.activeElement.textContent")).to eq("Open third")

      press_escape
      expect_closed("#second")
      expect(evaluate_script("document.activeElement.textContent")).to eq("Open second")

      press_escape
      expect_closed("#first")
      expect(evaluate_script("document.activeElement.textContent")).to eq("Open first")
      expect(backdrops).to eq(0)
    end

    it "stacks each one, with its backdrop, over the one beneath" do
      depths = evaluate_script(<<~JS)
        ['first', 'second', 'third'].map(id => {
          const dialog = document.getElementById(id)
          return [+getComputedStyle(dialog.previousElementSibling).zIndex, +getComputedStyle(dialog).zIndex]
        })
      JS

      expect(depths).to eq([[2000, 2000], [2001, 2001], [2002, 2002]])
    end

    # Rendered earlier in the page than the top one, so a tie in z-index would put it beneath
    it "puts one opened after closing one in the middle on top, not level with the top one" do
      run_stream(%(<%= turbo_stream.open_modal("unrelated") %>))
      expect_open("#unrelated")
      execute_script("document.getElementById('second').close()")
      expect_closed("#second")
      expect_closed("#third") # opened from it, so it goes too
      expect(open_modals).to eq(%w[first unrelated])

      run_stream(%(<%= turbo_stream.open_modal("second") %>))
      expect_open("#second")

      expect(element_at(700, 700)).not_to eq("modal-backdrop")
      expect(evaluate_script("document.getElementById('second').contains(document.elementFromPoint(700, 700))")).to be(true)
    end

    it "keeps a modal opened from code with no opener, which outlives the rest, on top" do
      run_stream(%(<%= turbo_stream.open_modal("unrelated") %>))
      expect_open("#unrelated")

      within("#unrelated") { expect(page).to have_button("Unrelated button") }
      expect(element_at(5, 5)).to eq("modal-backdrop")
      press_escape
      expect_closed("#unrelated")
      expect(open_modals).to eq(%w[first second third])
    end

    it "keeps focus in the top one when one beneath is closed from code" do
      execute_script("document.getElementById('second').close()")

      expect_closed("#second")
      expect_closed("#third") # opened from it
      expect(open_modals).to eq(["first"])
      5.times do
        press_tab
        expect(evaluate_script("!!document.activeElement.closest('#first')")).to be(true)
      end
    end
  end

  context "triggers" do
    before do
      insert(<<~ERB)
        <%= modal "Target", id: "target" do %>
          <iframe id="lazy_frame" data-src="about:blank#loaded" title="Lazy"></iframe>
          <button type="button" id="target_button">Target button</button>
        <% end %>
        <div style="position: fixed; top: 80px; left: 400px; z-index: 1000; background: white">
          <a href="/my/cards" id="link_trigger" data-modal="target">Link trigger</a>
          <a href="#" id="hash_trigger" data-modal="target">Hash trigger</a>
          <form action="/my/cards" method="get" id="trigger_form"><button id="form_trigger" data-modal="target">Form trigger</button></form>
          <table><tr data-modal="target" id="row_trigger"><td>Row cell</td><td><a href="/my/cards" id="row_link">Row link</a></td><td><button type="button" id="row_button">Row button</button></td></tr></table>
          <button type="button" data-modal="nonexistent">Missing trigger</button>
          <button type="button" data-modal="target" id="icon_trigger"><svg width="20" height="20"><circle cx="10" cy="10" r="8"/></svg></button>
        </div>
      ERB
    end

    it "opens from a link without following it or adding a #" do
      click_on "Hash trigger"
      expect_open("#target")
      expect(page).to have_current_path(my_reimbursements_path)
      expect(evaluate_script("location.hash")).to eq("")

      press_escape
      click_on "Link trigger"
      expect_open("#target")
      expect(page).to have_current_path(my_reimbursements_path)
    end

    it "lets a modifier click on a link trigger through, without opening the modal" do
      prevented = lambda do |modifier|
        evaluate_script(<<~JS)
          (() => {
            let prevented
            // Last, to see what the modal's listener did, then stop the browser following it
            addEventListener('click', event => { prevented = event.defaultPrevented; event.preventDefault() }, { once: true })
            document.getElementById('link_trigger').dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, #{modifier}: true }))
            return prevented
          })()
        JS
      end

      expect(prevented.call(:metaKey)).to be(false)
      expect(prevented.call(:ctrlKey)).to be(false)
      expect(prevented.call(:shiftKey)).to be(false)
      expect(open_modals).to be_empty
    end

    it "opens from a button in a form without submitting it" do
      click_on "Form trigger"

      expect_open("#target")
      expect(page).to have_current_path(my_reimbursements_path)
    end

    it "opens from a click on an icon inside a trigger" do
      find("#icon_trigger circle").click

      expect_open("#target")
    end

    it "opens from a row, but not from a link or button inside it" do
      execute_script("document.getElementById('row_button').addEventListener('click', () => document.body.dataset.rowButton = true)")
      click_on "Row button"
      expect(page).to have_css("body[data-row-button]")
      expect(open_modals).to be_empty

      find("td", text: "Row cell").click
      expect_open("#target")
      press_escape
      expect_closed("#target")

      click_on "Row link"
      expect(page).to have_current_path("/my/cards")
    end

    it "does nothing, and throws nothing, for a trigger whose modal isn't on the page" do
      click_on "Missing trigger"

      expect(open_modals).to be_empty
      expect(backdrops).to eq(0)
    end

    it "loads an iframe it holds only once it opens" do
      expect(evaluate_script("document.getElementById('lazy_frame').getAttribute('src')")).to be_nil

      click_on "Hash trigger"

      expect(evaluate_script("document.getElementById('lazy_frame').getAttribute('src')")).to eq("about:blank#loaded")
    end

    it "opens once and adds one backdrop when its trigger is clicked twice quickly" do
      execute_script("const trigger = document.getElementById('hash_trigger'); trigger.click(); trigger.click()")

      expect_open("#target")
      expect(backdrops).to eq(1)
      press_escape
      expect_closed("#target")
      expect(backdrops).to eq(0)
      expect(settled("document.querySelectorAll('dialog[open]').length")).to eq(0)
    end

    it "closes once when its close button and backdrop are both clicked while it animates out" do
      click_on "Hash trigger"
      expect_open("#target")

      execute_script("document.querySelector('#target [data-modal-close]').click(); document.querySelector('.modal-backdrop').click()")

      expect_closed("#target")
      expect(backdrops).to eq(0)
      expect(focused_id).to eq("hash_trigger")
    end

    it "does nothing when closed from code while already closed" do
      execute_script("document.getElementById('target').close()")
      run_stream(%(<%= turbo_stream.open_modal("nonexistent") %>))

      expect(open_modals).to be_empty
    end
  end

  context "focus" do
    it "keeps Tab inside a modal that has nothing to focus" do
      insert(%(<%= modal id: "bare" do %><p>Nothing to focus</p><% end %><button type="button" data-modal="bare">Open bare</button>))
      click_on "Open bare"
      expect_open("#bare")

      3.times do
        press_tab
        expect(evaluate_script("!!document.activeElement.closest('#bare') || document.activeElement === document.body")).to be(true)
      end
      press_escape
      expect_closed("#bare")
    end

    # Like a PDF receipt's preview: keys pressed in an iframe go to its own document
    it "keeps focus out of an iframe that comes first, so Escape still closes it" do
      insert(%(<%= modal id: "framed" do %><iframe data-src="about:blank"></iframe><button type="button" id="after_frame" data-modal-close>Close</button><% end %><button type="button" data-modal="framed">Open framed</button>))
      click_on "Open framed"
      expect_open("#framed")

      expect(focused_id).to eq("after_frame")
      press_escape
      expect_closed("#framed")
    end

    it "focuses an autofocus field when it opens" do
      insert(%(<%= modal "Auto", id: "autofocused" do %><button type="button">Before</button><input id="autofocus_field" autofocus><% end %><button type="button" data-modal="autofocused">Open autofocused</button>))
      click_on "Open autofocused"

      expect(page).to have_field(id: "autofocus_field", focused: true)
    end

    it "skips disabled, hidden and inert controls when wrapping Tab" do
      insert(<<~ERB)
        <%= modal id: "skippy" do %>
          <button type="button" id="skip_first">First</button>
          <button type="button" id="skip_last">Last</button>
          <button type="button" disabled>Disabled</button>
          <button type="button" hidden>Hidden</button>
          <div inert><button type="button">Inert</button></div>
          <div style="visibility: hidden"><button type="button">Invisible</button></div>
        <% end %>
        <button type="button" data-modal="skippy">Open skippy</button>
      ERB
      click_on "Open skippy"
      expect_open("#skippy")
      execute_script("document.getElementById('skip_last').focus()")

      press_tab
      expect(focused_id).to eq("skip_first")
      page.driver.browser.keyboard.type([:shift, :tab])
      expect(focused_id).to eq("skip_last")
    end
  end

  context "scrolling" do
    before do
      execute_script("document.body.insertAdjacentHTML('beforeend', '<div id=spacer style=height:4000px></div>')")
      insert(%(<%= modal "Scrolled", id: "scrolled" do %><input id="scrolled_field"><% end %><button type="button" data-modal="scrolled" id="scrolled_trigger" style="position: fixed; top: 10px; left: 600px; z-index: 1000">Open scrolled</button>))
      execute_script("scrollTo(0, 1500)")
    end

    it "keeps the page where it was scrolled to while open and after closing" do
      click_on "Open scrolled"
      expect_open("#scrolled")
      expect(evaluate_script("scrollY")).to eq(1500)
      expect(page_overflow).to eq("hidden")

      press_escape
      expect_closed("#scrolled")
      expect(evaluate_script("scrollY")).to eq(1500)
      expect(page_overflow).to eq("visible")
    end
  end

  context "with a menu" do
    before do
      insert(<<~ERB)
        <%= modal "Menu holder", id: "menu_holder" do %>
          <div data-controller="menu">
            <button type="button" data-menu-target="toggle" data-action="menu#toggle">Modal options</button>
            <div data-menu-target="content" class="menu__content">
              <button type="button" data-modal="from_menu">Open from menu</button>
              <input id="menu_input" placeholder="Search">
            </div>
          </div>
        <% end %>
        <%= modal "From menu", id: "from_menu" do %><p>From menu body</p><% end %>
        <button type="button" data-modal="menu_holder">Open menu holder</button>
      ERB
      click_on "Open menu holder"
      expect_open("#menu_holder")
      click_on "Modal options"
      expect(page).to have_button("Open from menu")
    end

    it "renders the menu inside the modal and above it" do
      expect(evaluate_script("!!document.querySelector('#menu_holder > .menu__content, #menu_holder .menu__content')")).to be(true)
      button = find_button("Open from menu")
      expect(evaluate_script("(b => { const r = b.getBoundingClientRect(); return document.elementFromPoint(r.x + r.width / 2, r.y + r.height / 2) === b })(arguments[0])", button)).to be(true)
    end

    it "closes the menu, and takes it along, when the modal closes from its close button" do
      within("#menu_holder header") { find("[data-modal-close]").click }

      expect_closed("#menu_holder")
      expect(page).to have_no_button("Open from menu")
      expect(evaluate_script("document.querySelectorAll('.menu__content[data-turbo-temporary]').length")).to eq(0)
      press_escape # nothing left for it
    end

    it "closes the menu when the modal closes from its backdrop" do
      page.driver.browser.mouse.click(x: 5, y: 5)

      expect(page).to have_no_button("Open from menu")
      # The first click only closes the menu; the backdrop then closes the modal
      page.driver.browser.mouse.click(x: 5, y: 5)
      expect_closed("#menu_holder")
    end

    it "closes the menu, then the modal, when a modal is opened from the menu and closed" do
      click_on "Open from menu"
      expect_open("#from_menu")
      expect(page).to have_no_button("Open from menu")

      press_escape
      expect_closed("#from_menu")
      expect(open_modals).to eq(["menu_holder"])
      press_escape
      expect_closed("#menu_holder")
    end

    it "keeps the menu open when typing in its field, and Escape closes just the menu" do
      find("#menu_input").click
      find("#menu_input").send_keys("abc")
      expect(page).to have_button("Open from menu")

      press_escape
      expect(page).to have_no_button("Open from menu")
      expect(open_modals).to eq(["menu_holder"])
    end
  end

  context "Turbo" do
    it "leaves nothing open, blocking or trapping focus after a visit away and back" do
      insert(%(<%= modal "Visit", id: "visit" do %><a href="/my/cards">Cards</a><% end %><button type="button" data-modal="visit">Open visit</button>))
      click_on "Open visit"
      expect_open("#visit")

      execute_script("Turbo.visit('/my/cards')")
      expect(page).to have_current_path("/my/cards")
      expect(page).to have_no_css(".modal-backdrop", visible: :all)
      expect(page_overflow).to eq("visible")

      go_back
      expect(page).to have_current_path(my_reimbursements_path)
      expect(page).to have_no_css("dialog[open]", visible: :all)
      expect(page).to have_no_css(".modal-backdrop", visible: :all)
      click_on "Start report"
      expect_open("#create_reimbursement_report")
      press_escape
      expect_closed("#create_reimbursement_report")
    end

    it "closes a modal from a form inside it once it submits successfully" do
      insert(<<~ERB)
        <%= modal "Submitting", id: "submitting", data: { controller: "turbo-frame-modal", action: "turbo:submit-end->turbo-frame-modal#submitEnd" } do %>
          <form id="submitting_form"><button type="button">Send it</button></form>
        <% end %>
        <button type="button" data-modal="submitting">Open submitting</button>
      ERB
      click_on "Open submitting"
      expect_open("#submitting")

      # As Turbo reports a failed submission, and then a successful one
      submit_end = "document.getElementById('submitting_form').dispatchEvent(new CustomEvent('turbo:submit-end', { bubbles: true, detail: { success: %s } }))"
      execute_script(format(submit_end, "false"))
      expect(settled("document.getElementById('submitting').open")).to be(true)

      execute_script(format(submit_end, "true"))
      expect_closed("#submitting")
      expect(backdrops).to eq(0)
    end
  end

  context "SweetAlert" do
    it "closes a confirmation, then the modal, then nothing, one per Escape" do
      insert(%(<%= modal "Confirm in", id: "confirm_in" do %><%= button_to "Remove", "/", data: { turbo_confirm: "Really?" } %><% end %><button type="button" data-modal="confirm_in">Open confirm in</button>))
      click_on "Open confirm in"
      expect_open("#confirm_in")
      click_on "Remove"
      expect(page).to have_css(".swal-overlay--show-modal", text: "Really?")

      press_escape
      expect(page).to have_no_css(".swal-overlay--show-modal")
      expect(settled("document.getElementById('confirm_in').open")).to be(true)

      press_escape
      expect_closed("#confirm_in")
      expect(page).to have_current_path(my_reimbursements_path)
    end
  end
end
