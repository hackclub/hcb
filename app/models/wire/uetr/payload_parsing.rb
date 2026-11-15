# frozen_string_literal: true

class Wire
  module UETR
    # Shared readers for the raw values in Column's international wire payloads.
    module PayloadParsing
      private

      def parse_time(value)
        Time.zone.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      def money(amount, currency)
        return nil if amount.blank? || currency.blank?

        Money.from_cents(amount, currency)
      end

      def bank(bic)
        return nil if bic.blank?

        Tracking::Bank.new(bic)
      end

    end
  end

end
