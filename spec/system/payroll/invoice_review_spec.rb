# frozen_string_literal: true

require "rails_helper"

# Reviewing a contractor's invoice: clicking its row opens the attached invoice
# in the receipt modal, which is the only place to approve or reject it.
RSpec.describe "Contractor invoice review", type: :system do
  include ActionView::RecordIdentifier

  let(:manager) { create(:user) }
  let(:event) { create(:event) }
  let(:payee) { create(:payee, event:, display_name: "Fiona Hackworth") }
  let(:position) { create(:payroll_position, payee:, aasm_state: :onboarded) }
  let(:position_page) { payroll_position_path(position) }

  before do
    # Flipper's instance is thread-local, so enabling it here wouldn't reach the app server
    allow(Flipper).to receive(:enabled?).and_call_original
    allow(Flipper).to receive(:enabled?).with(:payments_contractors_refresh_2026_06_26, event).and_return(true)
    allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
    allow_any_instance_of(Event).to receive(:balance_available_v2_cents).and_return(1_000_00)
    create(:organizer_position, user: manager, event:, role: :manager, first_time: false)
  end

  def create_invoice(name, amount_cents: 50_00, attachment: true)
    position.invoices.create!(name:, amount_cents:, currency: "USD").tap do |invoice|
      next unless attachment

      Receipt.create!(receiptable: invoice, user: create(:user), upload_method: :contractor_invoice,
                      file: { io: file_fixture("receipt.png").open, filename: "receipt.png" })
    end
  end

  # Modals fade in with jQuery; a click that lands mid-fade can miss its target
  def visit_without_animations(path)
    visit path
    page.execute_script("jQuery.fx.off = true")
  end

  # The rendered status, since a stray test-only favicon request can swallow the flash
  def have_invoice_status(status)
    have_css("tr", text: status, wait: 10)
  end

  # Clicks the row itself (its stretched link), away from the attachment thumbnail
  def open_row(text)
    find("tr.clickable", text:).find("a.stretched-link").click(x: 5, y: 5)
  end

  def open_invoice(invoice)
    open_row(invoice.name)
  end

  def within_invoice_modal(invoice, &)
    within("##{dom_id(invoice.receipts.first || invoice, :preview)}", &)
  end

  context "as a manager" do
    before { sign_in(manager) }

    it "approves only the invoice whose row was opened" do
      other = create_invoice("Week 1 hours", amount_cents: 75_00)
      invoice = create_invoice("Week 2 hours", amount_cents: 50_00)
      visit_without_animations position_page

      expect(page).to have_no_button("Approve").and have_no_button("Reject")
      expect(page).to have_css("h3 .contractor-review-badge", text: "2")

      open_invoice(invoice)
      within_invoice_modal(invoice) do
        expect(page).to have_button("Reject")
        click_button "Approve"
      end

      expect(page).to have_invoice_status("Approved")
      expect(page).to have_css("h3 .contractor-review-badge", text: "1")
      expect(invoice.reload).to be_approved
      expect(other.reload).to be_submitted
      expect(Payment.sole.amount_cents).to eq(50_00)
    end

    it "rejects only after the confirmation, which shows above the modal" do
      invoice = create_invoice("Week 1 hours")
      visit_without_animations position_page
      open_invoice(invoice)

      within_invoice_modal(invoice) { click_button "Reject" }
      within(".swal-modal") { click_button "Cancel" }
      expect(page).to have_no_css(".swal-modal")
      expect(invoice.reload).to be_submitted

      within_invoice_modal(invoice) { click_button "Reject" }
      within(".swal-modal") { click_button "Confirm" }

      expect(page).to have_invoice_status("Rejected")
      expect(invoice.reload).to be_rejected
      expect(Payment.count).to eq(0)
    end

    it "pays nothing when the invoice was reviewed while the modal was open" do
      invoice = create_invoice("Week 1 hours")
      visit_without_animations position_page
      open_invoice(invoice)
      invoice.mark_rejected!(create(:user))

      within_invoice_modal(invoice) { click_button "Approve" }

      expect(page).to have_invoice_status("Rejected")
      expect(invoice.reload).to be_rejected
      expect(Payment.count).to eq(0)
    end

    it "offers no review actions on an invoice that was already reviewed" do
      invoice = create_invoice("Week 1 hours")
      invoice.mark_rejected!(manager)
      visit_without_animations position_page
      open_invoice(invoice)

      within_invoice_modal(invoice) { expect(page).to have_text("receipt.png") }
      expect(page).to have_no_button("Approve", visible: :all)
      expect(page).to have_no_button("Reject", visible: :all)
      expect(page).to have_no_css("h3 .contractor-review-badge")
    end

    it "reviews an invoice without an attachment from a modal, never from the table" do
      invoice = create_invoice("Week 1 hours", attachment: false)
      visit_without_animations position_page

      expect(page).to have_no_button("Approve").and have_no_button("Reject")

      open_invoice(invoice)
      within_invoice_modal(invoice) do
        expect(page).to have_text("no attachment to preview")
        click_button "Approve"
      end

      expect(page).to have_invoice_status("Approved")
      expect(invoice.reload).to be_approved
    end

    it "offers no review actions on a reviewed invoice without an attachment" do
      invoice = create_invoice("Week 1 hours", attachment: false)
      invoice.mark_rejected!(manager)
      visit_without_animations position_page
      open_invoice(invoice)

      within_invoice_modal(invoice) { expect(page).to have_text("no attachment to preview") }
      expect(page).to have_no_button("Approve", visible: :all)
      expect(page).to have_no_button("Reject", visible: :all)
    end

    it "keeps the review actions on screen when the details outgrow the modal" do
      manager.update!(access_level: :admin) # only admins see a receipt's extracted text
      invoice = create_invoice("Week 1 hours")
      invoice.receipts.sole.update_columns(textual_content: "A very long line of extracted text\n" * 2000)
      page.driver.resize(1000, 700)
      visit_without_animations position_page
      open_invoice(invoice)

      on_screen = within_invoice_modal(invoice) do
        page.evaluate_script(<<~JS, find_button("Approve"))
          (button => {
            const { left, top, bottom, width, height } = button.getBoundingClientRect()
            return bottom <= window.innerHeight && document.elementFromPoint(left + width / 2, top + height / 2) === button
          })(arguments[0])
        JS
      end
      expect(on_screen).to be(true)
    end

    it "opens the invoice above the contractor popover on the contractors page" do
      invoice = create_invoice("Week 1 hours")
      visit_without_animations event_contractors_path(event_id: event.slug)

      open_row("Fiona Hackworth")
      open_invoice(invoice)
      within_invoice_modal(invoice) { click_button "Approve" }

      expect(page).to have_invoice_status("Approved")
      expect(invoice.reload).to be_approved
    end
  end

  context "as a reader" do
    it "shows the invoice without any way to review it" do
      reader = create(:user)
      create(:organizer_position, user: reader, event:, role: :reader, first_time: false)
      invoice = create_invoice("Week 1 hours")
      sign_in(reader)
      visit_without_animations position_page
      open_invoice(invoice)

      within_invoice_modal(invoice) { expect(page).to have_text("receipt.png") }
      expect(page).to have_no_button("Approve", visible: :all)
      expect(page).to have_no_button("Reject", visible: :all)
      expect(page).to have_no_css("h3 .contractor-review-badge")
    end
  end
end
