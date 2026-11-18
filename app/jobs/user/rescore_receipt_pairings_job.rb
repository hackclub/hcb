# frozen_string_literal: true

class User
  # Re-runs pairing suggestions for a cardholder's receipt bin when one of their
  # card charges is authorized or settles, so receipts uploaded before the
  # charge existed still get paired.
  class RescoreReceiptPairingsJob < ApplicationJob
    queue_as :low

    RECEIPT_LOOKBACK = 60.days
    MAX_RECEIPTS = 25

    def perform(user_id:)
      # Already-extracted receipts only: the rest still have their own suggestion job pending
      Receipt.in_receipt_bin
             .where(user_id:, data_extracted: true)
             .where(created_at: RECEIPT_LOOKBACK.ago..)
             .order(created_at: :desc)
             .limit(MAX_RECEIPTS)
             .each { |receipt| ::ReceiptService::Suggest.new(receipt:).run! }
    end

  end

end
