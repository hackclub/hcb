# frozen_string_literal: true

class ColumnService
  module Uetr
    # Presents Column's international wire transfer object.
    class Transfer
      STATUSES = {
        "pre_review"         => { label: "Pre-review", style: "muted" },
        "hold"               => { label: "On hold", style: "warning" },
        "canceled"           => { label: "Canceled", style: "error" },
        "initiated"          => { label: "Initiated", style: "pending" },
        "manual_review"      => { label: "Manual review", style: "warning" },
        "pending_review"     => { label: "Pending review", style: "warning" },
        "pending_submission" => { label: "Pending submission", style: "pending" },
        "submitted"          => { label: "Submitted to SWIFT", style: "pending" },
        "completed"          => { label: "Settled by Column", style: "success" },
        "pending_return"     => { label: "Return in progress", style: "warning" },
        "returned"           => { label: "Returned", style: "error" }
      }.freeze

      def self.fetch(id)
        return nil if id.blank?

        new(ColumnService.international_wire(id))
      end

      def initialize(payload)
        @payload = payload || {}
      end

      def id = @payload["id"]
      def status = @payload["status"]
      def description = @payload["description"].presence
      def beneficiary_name = @payload["beneficiary_name"].presence
      def fx_rate = @payload["fx_rate"].presence
      def return_reason = @payload["return_reason"].presence
      def incoming? = @payload["is_incoming"].present?

      def presentation = STATUSES.fetch(status, { label: status.to_s.humanize.presence || "Unknown", style: "muted" })
      def label = presentation[:label]
      def style = presentation[:style]

      def amount = money(@payload["amount"], @payload["currency_code"])
      def instructed_amount = money(@payload["instructed_amount"], @payload["instructed_currency_code"])
      def settled_amount = money(@payload["settled_amount"], @payload["settled_currency_code"])
      def returned_amount = money(@payload["returned_amount"], @payload["returned_currency_code"])

      def charge_bearer = Tracking::Event::CHARGE_BEARERS[@payload["charge_bearer"]]

      def beneficiary_bank = bank(@payload["beneficiary_fi"])
      def intermediary_banks = Array(@payload["intermediary_fis"]).filter_map { |bic| bank(bic) }

      # Column's own fees, which the SWIFT tracking feed never reports.
      def fees
        {
          "Column fee"   => money(@payload["column_fixed_fee"], "USD"),
          "Platform fee" => money(@payload["platform_fixed_fee"], "USD"),
          "FX fee"       => money(@payload["platform_fx_fee"], "USD")
        }.compact.reject { |_, fee| fee.zero? }
      end

      # Column's internal lifecycle, in the order the wire moves through it.
      def milestones
        {
          "Initiated"     => time("initiated_at"),
          "On hold"       => time("hold_at"),
          "Manual review" => time("manual_review_at"),
          "Submitted"     => time("submitted_at"),
          "Settled"       => time("completed_at"),
          "Returned"      => time("returned_at"),
          "Canceled"      => time("canceled_at")
        }.compact
      end

      private

      def time(key)
        Time.zone.parse(@payload[key].to_s)
      rescue ArgumentError, TypeError
        nil
      end

      def bank(bic)
        return nil if bic.blank?

        Tracking::Bank.new(bic)
      end

      def money(amount, currency)
        return nil if amount.blank? || currency.blank?

        Money.from_cents(amount, currency)
      end

    end
  end

end
