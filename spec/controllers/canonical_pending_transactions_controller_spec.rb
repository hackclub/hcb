# frozen_string_literal: true

require "rails_helper"

RSpec.describe CanonicalPendingTransactionsController do
  include SessionSupport
  render_views

  describe "#set_category" do
    it "sets the transaction category" do
      user = create(:user, :make_admin)
      cpt = create(:canonical_pending_transaction)
      sign_in(user)

      post(:set_category, params: { id: cpt.id, canonical_pending_transaction: { category_name: "Donations" } }, as: :html)

      expect(flash[:success]).to eq("Transaction category was successfully updated.")
      expect(response).to redirect_to(canonical_pending_transaction_path(cpt))

      cpt.reload
      expect(cpt.category.name).to eq("Donations")
      expect(cpt.category_mapping.assignment_strategy).to eq("manual")
    end
  end

  it "clears the transaction category if the param is blank" do
    user = create(:user, :make_admin)
    cpt = create(:canonical_pending_transaction, category_name: "Donations")
    sign_in(user)

    post(:set_category, params: { id: cpt.id, canonical_pending_transaction: { category_name: "" } }, as: :html)

    expect(flash[:success]).to eq("Transaction category was successfully updated.")
    expect(response).to redirect_to(canonical_pending_transaction_path(cpt))

    expect(cpt.reload.category).to be_nil
  end
end
