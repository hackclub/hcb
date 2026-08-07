# frozen_string_literal: true

require "rails_helper"

RSpec.describe CanonicalTransactionsController do
  include SessionSupport
  render_views

  describe "#set_custom_memo" do
    # `custom_memo` lives on the canonical transaction *and* on its ledger item,
    # which caches `memo` from its own copy. Renaming has to write both, or the
    # ledger keeps showing the old memo.
    it "renames the ledger item alongside the canonical transaction" do
      user = create(:user, :make_admin)
      ct = create(:canonical_transaction)
      create_session(user, verified: true)

      post(:set_custom_memo, params: { id: ct.id, canonical_transaction: { custom_memo: "Snacks at Shelburne Market" } }, as: :html)

      expect(ct.reload.custom_memo).to eq("Snacks at Shelburne Market")
      expect(ct.ledger_item.reload.custom_memo).to eq("Snacks at Shelburne Market")
      expect(ct.ledger_item.memo).to eq("Snacks at Shelburne Market")
    end

    it "clears the memo on both records when submitted blank" do
      user = create(:user, :make_admin)
      ct = create(:canonical_transaction)
      create_session(user, verified: true)
      ct.local_hcb_code.update_custom_memo!("Snacks at Shelburne Market")

      post(:set_custom_memo, params: { id: ct.id, canonical_transaction: { custom_memo: "" } }, as: :html)

      expect(ct.reload.custom_memo).to be_nil
      expect(ct.ledger_item.reload.custom_memo).to be_nil
    end
  end

  describe "#set_category" do
    it "sets the transaction category" do
      user = create(:user, :make_admin)
      ct = create(:canonical_transaction)
      create_session(user, verified: true)

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
    create_session(user, verified: true)

    post(:set_category, params: { id: ct.id, canonical_transaction: { category_slug: "" } }, as: :html)

    expect(flash[:success]).to eq("Transaction category was successfully updated.")
    expect(response).to redirect_to(canonical_transaction_path(ct))

    expect(ct.reload.category).to be_nil
  end
end
