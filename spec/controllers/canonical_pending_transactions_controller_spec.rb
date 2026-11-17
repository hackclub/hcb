# frozen_string_literal: true

require "rails_helper"

RSpec.describe CanonicalPendingTransactionsController do
  include SessionSupport
  render_views

  describe "#show" do
    it "renders a sub-organization's pending transaction for a manager of the parent organization" do
      parent_event = create(:event)
      manager = create(:user)
      create(:organizer_position, user: manager, event: parent_event, role: :manager)
      cpt = create(:canonical_pending_transaction, event: create(:event, parent: parent_event))
      create_session(manager, verified: true)

      get :show, params: { id: cpt.id }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "#set_category" do
    it "sets the transaction category" do
      user = create(:user, :make_admin)
      cpt = create(:canonical_pending_transaction)
      create_session(user, verified: true)

      post(:set_category, params: { id: cpt.id, canonical_pending_transaction: { category_slug: "rent" } }, as: :html)

      expect(flash[:success]).to eq("Transaction category was successfully updated.")
      expect(response).to redirect_to(canonical_pending_transaction_path(cpt))

      cpt.reload
      expect(cpt.category.slug).to eq("rent")
      expect(cpt.category_mapping.assignment_strategy).to eq("manual")
    end
  end

  it "clears the transaction category if the param is blank" do
    user = create(:user, :make_admin)
    cpt = create(:canonical_pending_transaction, category_slug: "rent")
    create_session(user, verified: true)

    post(:set_category, params: { id: cpt.id, canonical_pending_transaction: { category_slug: "" } }, as: :html)

    expect(flash[:success]).to eq("Transaction category was successfully updated.")
    expect(response).to redirect_to(canonical_pending_transaction_path(cpt))

    expect(cpt.reload.category).to be_nil
  end
end
