# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Incomplete payout method", type: :system do
  let(:user) { create(:user, full_name: "Fiona Hackworth") }
  let(:event) { create(:event) }
  # Wise methods added before the date of birth was required don't have one
  let!(:payout_method) do
    user.personal_legal_entity.payout_methods.create!(default: true, details: create(:wise_transfer_payout_method_details)).tap do |payout_method|
      payout_method.details.update!(recipient_birthday: nil)
    end
  end

  def enter_birthday(month, day, year)
    find("[data-segmented-data-input-target=month]").execute_script("this.focus()")
    page.driver.browser.keyboard.type(month, day, year)
  end

  # Pages render their views for the first time here, which can outlast Capybara's default wait
  def expect_saved
    expect(page).to have_text("Payout method updated.", wait: 10)
  end

  def stored_birthday
    payout_method.details.reload.recipient_birthday
  end

  it "is flagged on My reimbursements until it's completed in settings" do
    sign_in(user)
    visit my_reimbursements_path

    expect(page).to have_text("Your payout method needs attention")
    click_on "Update payout method"

    expect(page).to have_current_path(settings_payouts_path, wait: 10)
    enter_birthday("01", "15", "1990")
    click_on "Save details"
    expect_saved

    visit my_reimbursements_path
    expect(page).to have_no_text("Your payout method needs attention")
    expect(stored_birthday).to eq("01/15/1990")
  end

  context "with a report waiting on it" do
    let!(:report) do
      create(:reimbursement_report, user:, event:, aasm_state: :reimbursement_requested, legal_entity_payout_method: payout_method, currency: "GBP").tap do |report|
        report.expenses.create!(value: 12.34, memo: "Stickers")
      end
    end

    # The report page estimates the Wise transfer in USD
    before do
      allow(WiseTransfer).to receive(:generate_detailed_quote).and_return(
        with_fees_usd_amount: Money.from_amount(16, "USD"), without_fees_usd_amount: Money.from_amount(15, "USD")
      )
    end

    it "lets the submitter complete it from the report, though the report locks the method" do
      sign_in(user)
      visit reimbursement_report_path(report)

      expect(page).to have_text("complete your payout information")
      click_on "Edit payout information"

      within "#edit_payout" do
        expect(page).to have_no_button("Edit")
        enter_birthday("01", "15", "1990")
        click_on "Save details"
      end

      expect_saved
      expect(page).to have_current_path(reimbursement_report_path(report))
      expect(page).to have_no_text("complete your payout information")
      expect(stored_birthday).to eq("01/15/1990")
    end

    it "tells organizers they're waiting on the submitter" do
      manager = create(:user)
      create(:organizer_position, user: manager, event:, role: :manager)
      sign_in(manager)

      visit reimbursement_report_path(report)

      expect(page).to have_text("Waiting on Fiona")
      expect(page).to have_no_link("Edit payout information")
    end
  end
end
