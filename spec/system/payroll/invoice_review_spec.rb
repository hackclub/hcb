# frozen_string_literal: true

require "rails_helper"

# Reviewing a contractor's invoice: clicking its row on the contractor's page
# opens the invoice's own page, which is the only place to approve or reject it.
RSpec.describe "Contractor invoice review", type: :system do
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
    position.invoices.create!(name:, amount_cents:, currency: "USD", start_date: position.start_date, end_date: position.start_date).tap do |invoice|
      next unless attachment

      Receipt.create!(receiptable: invoice, user: create(:user), upload_method: :contractor_invoice,
                      file: { io: file_fixture("receipt.png").open, filename: "receipt.png" })
    end
  end

  # Opens the invoice the way a reviewer does: by clicking its row on the contractor's page
  def open_invoice(invoice)
    visit position_page
    find("tr.clickable", text: invoice.name).find("a.stretched-link").click
    expect(page).to have_current_path(payroll_invoice_path(invoice), wait: 10)
  end

  def have_invoice_status(status)
    have_css("aside .badge", text: status, wait: 10)
  end

  context "as a manager" do
    before { sign_in(manager) }

    it "approves only the invoice whose row was opened" do
      other = create_invoice("Week 1 hours", amount_cents: 75_00)
      invoice = create_invoice("Week 2 hours", amount_cents: 50_00)
      visit position_page

      expect(page).to have_no_button("Approve").and have_no_button("Reject")
      expect(page).to have_css("h3 .contractor-review-badge", text: "2")

      open_invoice(invoice)
      expect(page).to have_text("receipt.png")
      expect(page).to have_text("$50.00")
      expect(page).to have_button("Reject")
      click_button "Approve"

      expect(page).to have_invoice_status("Approved")
      expect(page).to have_current_path(payroll_invoice_path(invoice))
      expect(page).to have_no_button("Approve")
      expect(invoice.reload).to be_approved
      expect(other.reload).to be_submitted
      expect(Payment.sole.amount_cents).to eq(50_00)
    end

    it "rejects only after the confirmation" do
      invoice = create_invoice("Week 1 hours")
      open_invoice(invoice)

      click_button "Reject"
      within(".swal-modal") { click_button "Cancel" }
      expect(page).to have_no_css(".swal-modal")
      expect(invoice.reload).to be_submitted

      click_button "Reject"
      within(".swal-modal") { click_button "Confirm" }

      expect(page).to have_invoice_status("Rejected")
      expect(invoice.reload).to be_rejected
      expect(Payment.count).to eq(0)
    end

    it "pays nothing when the invoice was reviewed while the page was open" do
      invoice = create_invoice("Week 1 hours")
      open_invoice(invoice)
      invoice.mark_rejected!(create(:user))

      click_button "Approve"

      expect(page).to have_text("This invoice has already been reviewed.")
      expect(page).to have_invoice_status("Rejected")
      expect(invoice.reload).to be_rejected
      expect(Payment.count).to eq(0)
    end

    it "offers no review actions on an invoice that was already reviewed" do
      invoice = create_invoice("Week 1 hours")
      invoice.mark_rejected!(manager)
      visit position_page
      expect(page).to have_no_css("h3 .contractor-review-badge")

      open_invoice(invoice)
      expect(page).to have_text("receipt.png")
      expect(page).to have_no_button("Approve", visible: :all)
      expect(page).to have_no_button("Reject", visible: :all)
    end

    it "reviews an invoice without an attachment from its page" do
      invoice = create_invoice("Week 1 hours", attachment: false)
      open_invoice(invoice)

      expect(page).to have_text("No attachment")
      click_button "Approve"

      expect(page).to have_invoice_status("Approved")
      expect(invoice.reload).to be_approved
    end

    it "goes back to the contractor's page" do
      invoice = create_invoice("Week 1 hours")
      open_invoice(invoice)

      click_link "Back to Fiona Hackworth's contract"

      expect(page).to have_current_path(position_page)
    end
  end

  context "as a reader" do
    it "shows the invoice without any way to review it" do
      reader = create(:user)
      create(:organizer_position, user: reader, event:, role: :reader, first_time: false)
      invoice = create_invoice("Week 1 hours")
      sign_in(reader)

      open_invoice(invoice)

      expect(page).to have_text("receipt.png")
      expect(page).to have_no_button("Approve", visible: :all)
      expect(page).to have_no_button("Reject", visible: :all)
    end
  end
end
