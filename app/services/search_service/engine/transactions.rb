# frozen_string_literal: true

module SearchService
  class Engine
    class Transactions
      include SearchService::Shared
      def initialize(query, user, context)
        @query = query
        @user = user
        @admin = user.admin?
        @context = context
      end

      def run
        if @context[:event_id] && @query["types"].length == 1
          transactions = Event.find(@context[:event_id]).canonical_transactions
        elsif @admin
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
            transactions = transactions.where("canonical_transactions.date #{condition[:operator]} ?", value)
          when "amount"
            value = (convert_to_float(condition[:value]) * 100).to_i
            transactions = transactions.where("ABS(canonical_transactions.amount_cents) #{condition[:operator]} ?", value)
          end
        end
        if @query["subtype"]
          return transactions.search_memo(@query["query"]).select(&types["transaction"]["subtypes"][@query["subtype"]]).first(50)
        else
          return transactions.search_memo(@query["query"]).first(50)
        end
      end

    end

  end
end
