# frozen_string_literal: true

require "rails_helper"

# The transfer form disables every panel but the chosen one, and each panel has
# its own name and amount fields, so this checks the payment panel's are the
# ones sent.
RSpec.describe "Sending a payment to another organization", type: :system do
  let(:user) { create(:user) }
  let!(:source_event) { create(:event, :with_positive_balance, organizers: [user]) }
  let!(:destination_event) { create(:event, organizers: [user]) }

  before { sign_in(user) }

  it "sends the payment with the chosen category on both sides" do
    visit new_disbursement_path(source_event_id: source_event.slug, event_id: destination_event.slug)

    find("label", text: "Payment").click
    fill_in "What is the payment for?", with: "Hackathon T-shirts"
    select "Project supplies", from: "Category"
    within("fieldset[data-type='payment']") { fill_in "Amount", with: "42" }
    click_on "Send transfer"

    expect(page).to have_no_current_path(new_disbursement_path, ignore_query: true)
    disbursement = Disbursement.last
    expect(disbursement).to have_attributes(transfer_type: "payment", name: "Hackathon T-shirts", amount: 42_00)
    expect(disbursement.source_transaction_category.slug).to eq("project-supplies")
    expect(disbursement.destination_transaction_category.slug).to eq("project-supplies")
  end
end
