# frozen_string_literal: true

class User
  class ReceiptBin
    def initialize(user)
      @user = user
    end

    def suggested_receipt_pairings
      receipt_ids = Receipt.in_receipt_bin.where(user: @user).select(:id)
      # Don't suggest receipts ignored more than twice
      ineligible_receipt_ids = SuggestedPairing.ignored.where(receipt_id: receipt_ids).group(:receipt_id).having("COUNT(*) >= 2").select(:receipt_id)

      SuggestedPairing
        .unreviewed
        .where(receipt_id: receipt_ids)
        .where.not(receipt_id: ineligible_receipt_ids)
        .where("distance <= ?", ReceiptService::Suggest::SHOWN_DISTANCE) # With at least a certain confidence level
        # Drop transactions that got a receipt elsewhere before picking each receipt's closest pairing
        .where("NOT EXISTS (SELECT 1 FROM receipts r WHERE r.receiptable_type = 'HcbCode' AND r.receiptable_id = suggested_pairings.hcb_code_id)")
        .where(hcb_code_id: HcbCode.where(marked_no_or_lost_receipt_at: nil).select(:id))
        .order(:receipt_id, distance: :asc)
        .select("DISTINCT ON (receipt_id) suggested_pairings.*")
        .select { |pairing| pairing.hcb_code.missing_receipt? }
    end

  end

end
