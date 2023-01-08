# frozen_string_literal: true

require "rails_helper"

RSpec.describe CanonicalTransactionService::SetFriendlyMemo, type: :model do
  let(:canonical_transaction) { create(:canonical_transaction) }
  let(:friendly_memo) { " Friendly Memo " }

  let(:attrs) do
    {
      canonical_transaction_id: canonical_transaction.id,
      friendly_memo: friendly_memo
    }
  end

  let(:service) { CanonicalTransactionService::SetFriendlyMemo.new(attrs) }

  it "sets friendly memo" do
    service.run

    expect(canonical_transaction.reload.friendly_memo).to eql("FRIENDLY MEMO")
  end

  context "friendly memo is empty string" do
    let(:friendly_memo) { " " }

    it "sets friendly memo nil" do
      service.run

      expect(canonical_transaction.reload.friendly_memo).to eql(nil)
    end
  end

  context "friendly memo is nil" do
    let(:friendly_memo) { nil }

    it "sets friendly memo" do
      service.run

      expect(canonical_transaction.reload.friendly_memo).to eql(nil)
    end
  end
end
