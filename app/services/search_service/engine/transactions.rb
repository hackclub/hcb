# frozen_string_literal: true

module SearchService
  class Engine
    class Transactions
      include SearchService::Shared
      include DynamicFilters

      def initialize(query, user, context)
        @query = query
        @user = user
        @auditor = user.auditor?
        @context = context
      end

      def run
        if @context[:event_id] && @query["types"].length == 1
          transactions = Event.find(@context[:event_id]).canonical_transactions
        elsif @auditor
          transactions = CanonicalTransaction
        else
          transactions = CanonicalTransaction.joins(:canonical_event_mapping).where(canonical_event_mapping: { event: @user.events })
        end
        if @context[:user_id] && @query["types"].length == 1
          user = User.find(@context[:user_id])
          sch_sid = user&.stripe_cardholder&.stripe_id
          transactions = transactions.stripe_transaction
                                     .where("raw_stripe_transactions.stripe_transaction->>'cardholder' = ?", sch_sid)
        end
        if @context[:card_stripe_id] && @query["types"].length == 1
          transactions = transactions.stripe_transaction
                                     .where("raw_stripe_transactions.stripe_transaction->>'card' = ?", @context[:card_stripe_id])
        end
        @query["conditions"]&.each do |condition|
          case condition[:property]
          when "date"
            value = Chronic.parse(condition[:value], context: :past)
            filter_by_column(transactions, :date, condition[:operator], value)
          when "amount"
            value = (convert_to_float(condition[:value]) * 100).to_i

            amount_cents = transactions.arel_table[:amount_cents]
            abs_amount = Arel::Nodes::NamedFunction.new("ABS", [amount_cents])

            filter_by_arel_node(transactions, abs_amount, condition[:operator], value)
          end
        end
        results = transactions.search_memo(@query["query"])
        check = types["transaction"]["subtypes"][@query["subtype"]] if @query["subtype"]
        return results.first(LIMIT) unless check

        # Narrow to the subtype in SQL, then confirm each row with its Ruby
        # check a batch at a time, stopping once there are enough matches.
        results = SUBTYPE_PREFILTERS[@query["subtype"]].call(results).preload(:local_hcb_code)
        matches = []
        offset = 0
        loop do
          batch = results.limit(LIMIT).offset(offset).to_a
          matches.concat(batch.select(&check))
          break if matches.size >= LIMIT || batch.size < LIMIT

          offset += LIMIT
        end
        matches.first(LIMIT)
      end

      LIMIT = 50

      hcb_codes = ->(*codes) { ->(relation) { relation.where(codes.map { "canonical_transactions.hcb_code LIKE ?" }.join(" OR "), *codes.map { |code| "HCB-#{code}-%" }) } }
      codes = TransactionGroupingEngine::Calculate::HcbCode

      # A SQL condition every match of a subtype meets (see the subtypes in
      # SearchService::Shared#types), so most rows are dropped by the database.
      SUBTYPE_PREFILTERS = {
        "ach_transfer"           => hcb_codes.call(codes::ACH_TRANSFER_CODE),
        "mailed_check"           => hcb_codes.call(codes::CHECK_CODE, codes::INCREASE_CHECK_CODE),
        "account_transfer"       => hcb_codes.call(codes::OUTGOING_DISBURSEMENT_CODE, codes::INCOMING_DISBURSEMENT_CODE),
        "card_charge"            => ->(relation) { relation.where(transaction_source_type: RawStripeTransaction.name) },
        "check_deposit"          => hcb_codes.call(codes::CHECK_DEPOSIT_CODE),
        "donation"               => hcb_codes.call(codes::DONATION_CODE),
        "invoice"                => hcb_codes.call(codes::INVOICE_CODE),
        "refund"                 => hcb_codes.call(codes::STRIPE_CARD_CODE, codes::STRIPE_FORCE_CAPTURE_CODE),
        "fiscal_sponsorship_fee" => ->(relation) {
          fee_payments = CanonicalEventMapping.joins(:fee).merge(Fee.hack_club_fee).select(:canonical_transaction_id)
          hcb_codes.call(codes::FEE_REVENUE_CODE).call(relation).or(relation.where(id: fee_payments))
        }
      }.freeze

    end

  end
end
