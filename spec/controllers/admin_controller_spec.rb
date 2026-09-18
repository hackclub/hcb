# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdminController do
  include SessionSupport

  describe "#disbursement_process" do
    render_views

    it "renders mission statements for the source and destination events" do
      admin = create(:user, :make_admin)
      source_event = create(:event, description: "Source mission statement")
      destination_event = create(:event, description: "Destination mission statement")
      disbursement = create(:disbursement, source_event:, event: destination_event)

      create_session(admin, verified: true)

      get :disbursement_process, params: { id: disbursement.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Source mission statement")
      expect(response.body).to include("Destination mission statement")
    end
  end

  describe "#ach_start_approval" do
    render_views

    it "renders the ach transfer event's mission statement" do
      admin = create(:user, :make_admin)
      event = create(:event, :with_positive_balance, description: "Money wiring mission statement")
      ach_transfer = create(:ach_transfer, event:)

      create_session(admin, verified: true)

      get :ach_start_approval, params: { id: ach_transfer.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Money wiring mission statement")
    end
  end

  describe "#transaction" do
    render_views

    let(:admin) { create(:user, :make_admin) }
    let(:original_event) { create(:event, name: "Originally mapped event") }
    let(:new_event) { create(:event, name: "Remapped event") }

    before { create_session(admin, verified: true) }

    def settled_three_months_ago
      travel_to(3.months.ago) { create(:canonical_transaction, transaction_source: create(:raw_plaid_transaction)) }
    end

    def set_event(canonical_transaction, event)
      CanonicalTransactionService::SetEvent.new(
        canonical_transaction_id: canonical_transaction.id,
        event_id: event&.id,
        user: admin
      ).run
    end

    it "warns when the transaction was mapped automatically in a previous month" do
      canonical_transaction = settled_three_months_ago
      travel_to(3.months.ago) { create(:canonical_event_mapping, canonical_transaction:, event: original_event) }

      get :transaction, params: { id: canonical_transaction.id }

      expect(response.body).to include("first mapped back in #{3.months.ago.strftime("%B %Y")}")
      expect(response.body).to include("REMAP #{canonical_transaction.id}")
    end

    it "warns about the month of the first mapping, not the most recent one" do
      canonical_transaction = settled_three_months_ago
      travel_to(3.months.ago) { set_event(canonical_transaction, original_event) }
      set_event(canonical_transaction, new_event)

      get :transaction, params: { id: canonical_transaction.id }

      expect(response.body).to include("first mapped back in #{3.months.ago.strftime("%B %Y")}")
      expect(response.body).to include("REMAP #{canonical_transaction.id}")
    end

    it "warns when a transaction mapped in a previous month has since been unmapped" do
      canonical_transaction = settled_three_months_ago
      travel_to(3.months.ago) { set_event(canonical_transaction, original_event) }
      set_event(canonical_transaction, nil)

      get :transaction, params: { id: canonical_transaction.id }

      expect(canonical_transaction.reload.canonical_event_mapping).to be_nil
      expect(response.body).to include("Are you absolutely sure you want to map this transaction?")
    end

    it "doesn't warn when the transaction has never been mapped" do
      canonical_transaction = settled_three_months_ago

      get :transaction, params: { id: canonical_transaction.id }

      expect(response.body).not_to include("REMAP #{canonical_transaction.id}")
    end

    it "doesn't warn when the transaction was first mapped this month" do
      canonical_transaction = create(:canonical_transaction, transaction_source: create(:raw_plaid_transaction))
      create(:canonical_event_mapping, canonical_transaction:, event: original_event)
      set_event(canonical_transaction, new_event)

      get :transaction, params: { id: canonical_transaction.id }

      expect(response.body).not_to include("REMAP #{canonical_transaction.id}")
    end
  end
end
