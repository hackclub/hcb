# frozen_string_literal: true

require "rails_helper"

RSpec.describe CanonicalTransactionsController do
  include SessionSupport
  render_views

  describe "#set_category" do
    it "sets the transaction category" do
      user = create(:user, :make_admin)
      ct = create(:canonical_transaction)
      sign_in(user)

      post(:set_category, params: { id: ct.id, canonical_transaction: { category_slug: "rent" } }, as: :html)

      expect(flash[:success]).to eq("Transaction category was successfully updated.")
      expect(response).to redirect_to(canonical_transaction_path(ct))

      ct.reload
      expect(ct.category.slug).to eq("rent")
      expect(ct.category_mapping.assignment_strategy).to eq("manual")
    end
  end

  it "clears the transaction category if the param is blank" do
    user = create(:user, :make_admin)
    ct = create(:canonical_transaction, category_slug: "rent")
    sign_in(user)

    post(:set_category, params: { id: ct.id, canonical_transaction: { category_slug: "" } }, as: :html)

    expect(flash[:success]).to eq("Transaction category was successfully updated.")
    expect(response).to redirect_to(canonical_transaction_path(ct))

    expect(ct.reload.category).to be_nil
  end
end
