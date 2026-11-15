# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Marking money in as a repayment", type: :system do
  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let(:income) { create(:canonical_transaction, event:, amount_cents: 300_00, memo: "Check from Sam") }
  let(:pizza) { create(:canonical_transaction, event:, amount_cents: -100_00, memo: "Pizza") }
  let(:snacks) { create(:canonical_transaction, event:, amount_cents: -200_00, memo: "Snacks") }

  before do
    create(:organizer_position, user:, event:, role: :member)
    pizza
    snacks
    sign_in(user)
    visit hcb_code_path(income.ledger_item.reload.hcb_code)
    find("[aria-label='More Options']").click
    click_on "Mark as a repayment"
  end

  it "can only be submitted once the chosen expenses add up to it" do
    within("#mark_repayment") do
      expect(page).to have_button("Mark as a repayment", disabled: true)
      expect(page).to have_text("$300.00 left to match")

      find("input[aria-label^='Repay Pizza' i]").check
      expect(page).to have_text("$200.00 left to match")
      expect(page).to have_button("Mark as a repayment", disabled: true)

      find("input[aria-label^='Repay Snacks' i]").check
      expect(page).to have_text("Adds up")

      click_button "Mark as a repayment"
    end
    click_button "Confirm"

    expect(page).to have_text("Marked as a repayment.")
    expect(income.ledger_item.reload.repaying_repayment.repaid_ledger_items).to contain_exactly(pizza.ledger_item, snacks.ledger_item)
  end
end
