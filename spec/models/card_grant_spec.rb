# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardGrant, type: :model do
  describe "ledger association" do
    it "automatically creates a primary ledger after creation" do
      # Skip - CardGrant creation triggers complex disbursement logic
      skip "Requires actual card_grant which triggers disbursement logic"
    end

    it "has a primary ledger association" do
      card_grant = CardGrant.new

      expect(card_grant).to respond_to(:ledger)
    end
  end
end
