# frozen_string_literal: true

class User
  class ReceiptBin
    def initialize(user)
      @user = user
    end

    def suggested_receipt_pairings
      @receipts = Receipt.in_receipt_bin.where(user: @user)
      # Don't suggest receipts ignored more than twice
      ineligible_receipt_ids = SuggestedPairing.ignored.group("receipt_id").having("COUNT(*) >= 2").pluck(:receipt_id)

      SuggestedPairing
        .unreviewed
        .where(receipt_id: @receipts.ids - ineligible_receipt_ids)
        .where("distance <= ?", 50) # With at least a certain confidence level
        # Only get the closest pairing for each receipt
        .order(:receipt_id, distance: :asc)
        .select("DISTINCT ON (receipt_id) suggested_pairings.*")
        # What the pairing card reads per item: the ledger row (see Ledger::Query#execute) plus the card's stripe_card through linked_object
        .preload(ledger_item: [:linked_object, :tags, :hcb_code, { primary_ledger: [:event, { card_grant: :event }] }])
        .select { |pairing| pairing.ledger_item.missing_receipt? }
    end

  end

end
