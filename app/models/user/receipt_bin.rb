# frozen_string_literal: true

class User
  class ReceiptBin
    def initialize(user)
      @user = user
    end

    def suggested_receipt_pairings
      return [] unless Flipper.enabled?(:receipt_bin_2023_04_07, @user)

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
        .select { |pairing| pairing.hcb_code.missing_receipt? }
    end

  end

end
