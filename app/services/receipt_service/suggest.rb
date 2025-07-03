# frozen_string_literal: true

module ReceiptService
  class Suggest
    include Turbo::Streams::ActionHelper
    include Turbo::Streams::StreamName

    def initialize(receipt:)
      @receipt = receipt
    end

    def run!(include_details: false)
      return nil if user.nil?
      return nil unless @receipt.has_textual_content?

      @extracted = ::ReceiptService::Extract.new(receipt: @receipt).run!

      pairings = transaction_distances(include_details:)

      if pairings.present?
        pairs = pairings.map do |pairing|
          {
            receipt_id: @receipt.id,
            hcb_code_id: pairing[:hcb_code].id,
            distance: pairing[:distance],
            aasm_state: "unreviewed"
          }
        end

        pairings = SuggestedPairing.upsert_all(pairs, unique_by: [:receipt_id, :hcb_code_id]) if pairs.any?

        if @receipt.receiptable.nil?
          content = turbo_stream_action_tag(:refresh_suggested_pairings)
          Turbo::StreamsChannel.broadcast_action_to([@receipt.user, :receipt_bin], action: :refresh_suggested_pairings)

          if @receipt.email_receipt_bin? && pair = @receipt.suggested_pairings
                                                           .unreviewed
                                                           .where("distance <= ?", 20)
                                                           .order(:receipt_id, distance: :asc)
                                                           .select("DISTINCT ON (receipt_id) suggested_pairings.*")
                                                           .select { |pairing| pairing.hcb_code.missing_receipt? }
                                                           .first
            pair.mark_accepted!
            ReceiptBinMailer.with(suggested_pairing: pair).paired.deliver_later
          end
        end

        pairings
      end
    end

    def distance(hcb_code)
      # Handle cases with bad data
      return 1_000 if @extracted.nil? ||
                      @extracted.extracted_total_amount_cents.nil? ||
                      @extracted.extracted_date.nil? ||
                      @extracted.extracted_card_last4.nil?

      distance = 0

      unless (@extracted.extracted_total_amount_cents.abs - hcb_code.amount_cents.abs).abs == 0
        distance += 200 # Automatically disqualify suggestion if not matching
      end

      unless @extracted.extracted_card_last4 == hcb_code.card&.last4
        distance += 200 # Automatically disqualify suggestion if not matching
      end

      unless hcb_code.stripe_merchant["postal_code"] == @extracted.extracted_merchant_zip_code
        distance += 10 # Weight suggestions towards those with matching zip codes
      end

      unless @extracted.extracted_merchant_name&.downcase&.in?(hcb_code.stripe_card_memo&.downcase)
        distance += 10 # Weight suggestions towards those with matching merchant names
      end

      date = (hcb_code.pt&.raw_pending_stripe_transaction&.created_at || hcb_code.date).to_date
      distance += (date - @extracted.extracted_date.to_date).abs.to_i * 50 / 7 # Allow 1 week of leeway before crossing the distance threshold of 50

      distance
    end

    def sorted_transactions
      transaction_distances.sort_by { |match| match[:distance] }
    end

    def best_match
      sorted_transactions.first
    end

    private

    def transaction_distances(include_details: false)
      potential_hcb_codes.map do |hcb_code|
        {
          hcb_code:,
          distance: distance(hcb_code)
        }
      end
    end

    def user
      @receipt.user
    end

    def potential_hcb_codes
      user.transactions_missing_receipt
    end

  end
end
