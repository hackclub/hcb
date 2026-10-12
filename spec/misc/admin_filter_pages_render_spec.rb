# frozen_string_literal: true

require "rails_helper"

# Smoke coverage for the shared admin filter bar (app/views/admin/filters/*).
# These pages have no other specs, so a render check is the cheapest guard
# against a mistyped partial local breaking an admin index.
RSpec.describe AdminController, type: :controller do
  include SessionSupport
  render_views

  filtered_actions = %i[
    events balances donations recurring_donations invoices sponsors reimbursements
    ach checks wires wise_transfers disbursements paypal_transfers increase_checks
    google_workspaces bank_fees account_numbers pending_ledger ledger ledger_items
    hcb_codes users emails employees employee_payments contracts applications
    raw_transactions stripe_cards stripe_card_personalization_designs
  ].freeze

  before { create_session(create(:user, :make_admin), verified: true) }

  filtered_actions.each do |action|
    it "renders the ##{action} filter bar" do
      get action
      expect(response).to have_http_status(:ok)
    end
  end
end

[
  Admin::PaymentsController,
  Admin::TaxFormsController,
  Admin::LegalEntitiesController,
  Admin::PayrollPositionsController,
  Admin::W9sController,
].each do |controller_class|
  RSpec.describe controller_class, type: :controller do
    include SessionSupport
    render_views

    it "renders the #index filter bar" do
      create_session(create(:user, :make_admin), verified: true)
      get :index
      expect(response).to have_http_status(:ok)
    end
  end
end
