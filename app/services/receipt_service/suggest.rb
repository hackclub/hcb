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
            ledger_item_id: pairing[:ledger_item].id,
            distance: pairing[:distance],
            aasm_state: "unreviewed"
          }
        end

        pairings = SuggestedPairing.upsert_all(pairs, unique_by: [:receipt_id, :ledger_item_id]) if pairs.any?

        if @receipt.receiptable.nil?
          content = turbo_stream_action_tag(:refresh_suggested_pairings)
          Turbo::StreamsChannel.broadcast_action_to([@receipt.user, :receipt_bin], action: :refresh_suggested_pairings)

          if @receipt.email_receipt_bin? && pair = @receipt.suggested_pairings
                                                           .unreviewed
                                                           .where("distance <= ?", 20)
                                                           .order(:receipt_id, distance: :asc)
                                                           .select("DISTINCT ON (receipt_id) suggested_pairings.*")
                                                           .select { |pairing| pairing.ledger_item.missing_receipt? }
                                                           .first
            pair.mark_accepted!

            return pair
          end
        end

        pairings
      end
    end

    # How far the receipt is from a card charge, from 0 (every feature the
    # extractor read off the receipt matches) to 100. The charge's amount, date,
    # card and merchant come from its Stripe authorization where there is one,
    # since that's what the cardholder saw at the time, and from the ledger item
    # otherwise.
    def distance(ledger_item)
      return if @extracted.nil?

      card_charge = ledger_item.linked_object if ledger_item.linked_object_type == "CardCharge"
      authorization = card_charge&.raw_pending_stripe_transaction&.stripe_transaction
      merchant_amount = authorization&.[]("merchant_amount")
      stripe_merchant = card_charge&.stripe_merchant_data || {}

      distances = {
        amount_cents: {
          value: @extracted.extracted_total_amount_cents && ((merchant_amount || ledger_item.amount_cents).abs - @extracted.extracted_total_amount_cents.abs).abs == 0 ? 0 : 1,
          weight: 200,
        },
        card_last_four: {
          value: @extracted.extracted_card_last4 == card_charge&.stripe_card&.last4 ? 0 : 1,
          weight: 200,
        },
        date: {
          value: begin
            if @extracted.extracted_date.present?
              distance = ((card_charge&.raw_pending_stripe_transaction&.created_at || ledger_item.datetime).to_date - @extracted.extracted_date.to_date).abs

              if distance <= 1
                0
              elsif distance <= 5
                0.2 + 0.8 * (distance / 5)
              else
                1
              end
            else
              1
            end
          end,
          weight: 100,
        },
        merchant_zip_code: {
          value: begin
            stripe_zip = stripe_merchant["postal_code"]
            if stripe_zip == "00000"
              nil
              # https://mapofzipcodes.com/blog/00000-zip-code
              # many postal codes are reported as 000000, and we don't
              # want a lack of information to hurt pairing suggestions
            else
              stripe_zip = stripe_zip.to_i
              receipt_zip = @extracted.extracted_merchant_zip_code.to_i
              distance = (stripe_zip - receipt_zip).abs
              if distance.zero?
                0
              elsif distance < 75
                0.5
              else
                1
              end
            end
          end,
          weight: 50,
        },
        merchant_name: {
          value: @extracted.extracted_merchant_name&.downcase&.in?(stripe_merchant["name"]&.downcase) ? 0 : 1,
          weight: 50,
        }
      }

      features = distances.values.reject { |data| data[:value].nil? }

      value = features.map { |data| data[:value] * data[:weight] }.sum.to_f
      weight = features.map { |data| data[:weight] }.sum.to_f

      value / weight * 100
    end

    private

    def transaction_distances(include_details: false)
      potential_ledger_items.map do |ledger_item|
        {
          ledger_item:,
          distance: distance(ledger_item)
        }
      end
    end

    def user
      @receipt.user
    end

    # The user's card charges missing a receipt. They still come as HCB codes
    # (see User#transactions_missing_receipt); a code without a ledger item
    # (none in practice: card charges always have a pending transaction, so
    # always a ledger item) can't be paired.
    def potential_ledger_items
      user.transactions_missing_receipt.includes(:ledger_item).filter_map(&:ledger_item)
    end

  end
end
