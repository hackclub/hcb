# frozen_string_literal: true

require "rails_helper"

RSpec.describe CanonicalPendingTransactionsController do
  include SessionSupport
  render_views

  describe "#update" do
    # `custom_memo` lives on the pending transaction *and* on its ledger item,
    # which caches `memo` from its own copy. Renaming has to write both, or the
    # ledger keeps showing the old memo.
    it "renames the ledger item alongside the pending transaction" do
      user = create(:user, :make_admin)
      cpt = create(:canonical_pending_transaction)
      create_session(user, verified: true)

      patch(:update, params: { id: cpt.id, canonical_pending_transaction: { custom_memo: "A shiver of Blåhaj" } }, as: :html)

      expect(cpt.reload.custom_memo).to eq("A shiver of Blåhaj")
      expect(cpt.ledger_item.reload.custom_memo).to eq("A shiver of Blåhaj")
      expect(cpt.ledger_item.memo).to eq("A shiver of Blåhaj")
    end

    it "clears the memo on both records when submitted blank" do
      user = create(:user, :make_admin)
      cpt = create(:canonical_pending_transaction)
      create_session(user, verified: true)
      cpt.local_hcb_code.update_custom_memo!("A shiver of Blåhaj")

      patch(:update, params: { id: cpt.id, canonical_pending_transaction: { custom_memo: "" } }, as: :html)

      expect(cpt.reload.custom_memo).to be_nil
      expect(cpt.ledger_item.reload.custom_memo).to be_nil
    end

    it "still updates the admin-only attributes" do
      user = create(:user, :make_admin)
      cpt = create(:canonical_pending_transaction, fronted: false)
      create_session(user, verified: true)

      patch(:update, params: { id: cpt.id, canonical_pending_transaction: { custom_memo: "Fronted transaction", fronted: true } }, as: :html)

      expect(cpt.reload.fronted).to be(true)
      expect(cpt.custom_memo).to eq("Fronted transaction")
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
