# frozen_string_literal: true

class CardCharge
  # Itemizes a card charge into its authorization, captures, and refunds, with
  # both the USD amount and the amount in the merchant's currency.
  class AmountBreakdown
    Entry = Struct.new(:kind, :amount, :merchant_amount, :occurred_at, keyword_init: true) do
      def label
        { authorization: "Authorized", decline: "Declined", capture: "Charged", refund: "Refunded" }.fetch(kind)
      end

      def foreign_currency?
        merchant_amount.present? && merchant_amount.currency != amount.currency
      end
    end

    def initialize(raw_pending_stripe_transaction:, raw_stripe_transactions:)
      @raw_pending_stripe_transaction = raw_pending_stripe_transaction
      @raw_stripe_transactions = raw_stripe_transactions.to_a
    end

    def entries
      @entries ||= [authorization_entry, *settled_entries].compact.sort_by(&:occurred_at)
    end

    def captures = entries.select { |entry| entry.kind == :capture }
    def refunds = entries.select { |entry| entry.kind == :refund }

    def refunded_amount = refunds.sum(Money.new(0, "USD"), &:amount)

    def charged_amount
      return captures.sum(Money.new(0, "USD"), &:amount) if captures.any?

      authorization_entry&.amount if authorization_entry&.kind == :authorization
    end

    def foreign_currency? = entries.any?(&:foreign_currency?)

    private

    def authorization_entry
      return nil if @raw_pending_stripe_transaction.nil?
      return @authorization_entry if defined?(@authorization_entry)

      authorization = @raw_pending_stripe_transaction.stripe_transaction
      request = authorization["request_history"]&.select { |r| r["approved"] }&.last

      @authorization_entry = Entry.new(
        kind: authorization["approved"] == false ? :decline : :authorization,
        amount: Money.new(@raw_pending_stripe_transaction.amount_cents.abs, "USD"),
        merchant_amount: merchant_money(request || authorization),
        occurred_at: timestamp(authorization) || @raw_pending_stripe_transaction.created_at
      )
    end

    def settled_entries
      @raw_stripe_transactions.map do |rst|
        transaction = rst.stripe_transaction

        Entry.new(
          kind: rst.refund? ? :refund : :capture,
          amount: Money.new(rst.amount_cents.abs, "USD"),
          merchant_amount: merchant_money(transaction),
          occurred_at: timestamp(transaction) || rst.created_at
        )
      end
    end

    def merchant_money(object)
      return nil if object.nil? || object["merchant_amount"].nil? || object["merchant_currency"].blank?

      Money.new(object["merchant_amount"].abs, object["merchant_currency"])
    end

    def timestamp(object)
      Time.at(object["created"]) if object["created"].present?
    end

  end

end
