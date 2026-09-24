# frozen_string_literal: true

class ColumnService
  module Uetr
    # Presents a SWIFT GPI tracking payload for display.
    # https://docs.column.com/api/international-wire/get-international-wire-tracking
    class Tracking
      # SWIFT's own tracking system posts updates under this BIC rather than a real bank.
      TRACKER_BIC = "TRCKCHZZXXX"

      STATUSES = {
        "completed" => { label: "Delivered", summary: "The recipient's bank credited the funds.", style: "success", icon: "check-circle-fill" },
        "rejected"  => { label: "Rejected", summary: "The recipient's bank rejected the transfer.", style: "error", icon: "flag-fill" },
        "pending"   => { label: "In transit", summary: "Moving through the SWIFT network.", style: "pending", icon: "send-fill" }
      }.freeze

      UNKNOWN_STATUS = { label: "Awaiting first update", summary: "SWIFT hasn't reported on this wire yet.", style: "muted", icon: "clock-fill" }.freeze

      CANCELLATIONS = {
        "pending"  => { label: "Recall requested", summary: "Waiting on the recipient's bank to answer the recall.", style: "warning" },
        "accepted" => { label: "Recall accepted", summary: "The funds are on their way back.", style: "info" },
        "rejected" => { label: "Recall refused", summary: "The bank won't return these funds.", style: "error" }
      }.freeze

      def initialize(payload)
        @payload = payload || {}
      end

      def uetr = @payload["uetr"]
      def id = @payload["id"]
      def status = @payload["transfer_status"]
      def status_reason = @payload["transfer_status_reason"].presence
      def cancellation_status = @payload["cancellation_status"].presence
      def cancellation_reason = @payload["cancellation_reason"].presence

      def delivered? = status == "completed"
      def rejected? = status == "rejected"
      def in_transit? = status == "pending"
      def settled? = delivered? || rejected?

      def presentation = STATUSES.fetch(status, UNKNOWN_STATUS)
      def label = presentation[:label]
      def summary = presentation[:summary]
      def style = presentation[:style]
      def icon = presentation[:icon]

      def cancellation = CANCELLATIONS[cancellation_status]

      # Anything that needs to be stated up front rather than found in the timeline.
      def callouts
        list = []

        if rejected?
          list << { label: "Rejected by the bank", summary: status_reason || "No reason was given by the bank.", style: "error", icon: "flag-fill" }
        end

        if cancellation.present?
          list << cancellation.merge(summary: cancellation_reason || cancellation[:summary], icon: "important-fill")
        end

        list
      end

      # The specific reason moves into a callout when there is one, so don't repeat it here.
      def header_summary = rejected? ? summary : (status_reason || summary)

      # Newest first: the latest hop is what someone checking on a wire came to see.
      def timeline_events = events.reverse

      def completed_at = parse_time(@payload["completed_at"])
      def updated_at = parse_time(@payload["updated_at"])
      def started_at = events.first&.occurred_at

      def duration
        finish = completed_at || updated_at
        return nil if started_at.nil? || finish.nil? || finish <= started_at

        finish - started_at
      end

      def events
        @events ||= Array(@payload["events"]).map { |event| Event.new(event) }
                                             .sort_by { |event| event.occurred_at || Time.zone.at(0) }
                                             .each_with_index { |event, index| event.first = index.zero? }
      end

      def delivered_amount
        money(@payload["completed_amount"], @payload["completed_currency_code"])
      end

      # The tracking object has no top-level instructed amount, so fall back to the
      # first hop that reported one.
      def sent_amount
        events.filter_map(&:instructed_amount).first
      end

      def headline_amount = delivered_amount || sent_amount

      def amount_label
        return "delivered" if delivered_amount.present?
        return "not delivered" if rejected?

        "on its way"
      end

      def charges
        events.flat_map(&:charges)
      end

      # Difference between what left Column and what recipient received
      def charges_from_delivery
        return nil if sent_amount.nil? || delivered_amount.nil?
        return nil unless sent_amount.currency == delivered_amount.currency

        difference = sent_amount - delivered_amount
        difference.positive? ? difference : nil
      end

      # Fees are only summable when every bank deducted in the same currency.
      def charges_from_events
        currencies = charges.map { |charge| charge.amount.currency }.uniq
        return nil unless currencies.one?

        charges.sum(Money.from_cents(0, currencies.first)) { |charge| charge.amount }
      end

      def total_charges = charges_from_delivery || charges_from_events

      # Distinct banks that have handled the wire, in the order they appeared.
      def banks
        events.filter_map(&:instructed_bank).uniq(&:bic)
      end

      Step = Struct.new(:name, :state, :detail, :at, keyword_init: true)

      Charge = Struct.new(:amount, :bank, keyword_init: true)

      def steps
        [
          Step.new(name: "Sent", state: "complete", at: started_at),
          Step.new(name: "In transit", state: settled? ? "complete" : "active", detail: banks_detail),
          terminal_step
        ]
      end

      private

      def terminal_step
        if rejected?
          # The reason is already stated in the callout above the stepper.
          Step.new(name: "Rejected", state: "failed")
        elsif delivered?
          Step.new(name: "Delivered", state: "complete", at: completed_at)
        else
          Step.new(name: "Delivered", state: "upcoming")
        end
      end

      def banks_detail
        return nil if banks.empty?

        "#{banks.count} #{"bank".pluralize(banks.count)}"
      end

      def parse_time(value)
        Time.zone.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      def money(amount, currency)
        return nil if amount.blank? || currency.blank?

        Money.from_cents(amount, currency)
      end

      # A bank identified only by its BIC. Column never sends institution names, but
      # characters 5-6 of a BIC are its ISO country code, so we can at least place it.
      class Bank
        attr_reader :bic

        def initialize(bic)
          @bic = bic
        end

        def tracker? = bic == TRACKER_BIC
        def name = tracker? ? "SWIFT tracking system" : bic

        def country
          return nil if tracker?

          @country ||= ISO3166::Country.new(bic[4, 2].to_s.upcase)
        end

        def country_name = country&.common_name
        def flag = country&.emoji_flag

      end

      class Event
        # Each of these also arrives prefixed with `fi_` for the bank-to-bank leg.
        LABELS = {
          "transfer_initiated"                     => "Forwarded to the next bank",
          "transfer_updated"                       => "Status update",
          "transfer_cancellation_requested"        => "Recall requested",
          "transfer_cancellation_responded"        => "Recall answered",
          "transfer_cancellation_tracking_updated" => "Recall tracking update",
          "transfer_return_initiated"              => "Return started",
          "transfer_return_updated"                => "Return update",
          "transfer_cover_initiated"               => "Cover payment sent",
          "transfer_cover_updated"                 => "Cover payment update",
          "transfer_cover_return_initiated"        => "Cover return started",
          "transfer_cover_return_updated"          => "Cover return update"
        }.freeze

        CHARGE_BEARERS = {
          "DEBT" => "Sender pays all fees",
          "CRED" => "Recipient pays all fees",
          "SHAR" => "Fees shared between sender and recipient"
        }.freeze

        attr_accessor :first

        def initialize(payload)
          @payload = payload || {}
        end

        def first? = !!@first
        def type = @payload["type"]
        def base_type = type.to_s.delete_prefix("fi_")
        def status = @payload["transfer_status"]
        def status_reason = @payload["transfer_status_reason"].presence
        def cancellation_status = @payload["cancellation_status"].presence
        def cancellation_reason = @payload["cancellation_reason"].presence
        def cancellation_status_reason = @payload["cancellation_status_reason"].presence
        def network_reference = @payload["network_reference"].presence
        def fx_rate = @payload["fx_rate"].presence
        def cover? = @payload["is_cover_transfer_event"].present?
        def bank_leg? = type.to_s.start_with?("fi_")

        def delivered? = status == "completed"
        def rejected? = status == "rejected"

        def occurred_at
          @occurred_at ||= Time.zone.parse(@payload["updated_at"].to_s)
        rescue ArgumentError, TypeError
          nil
        end

        def charge_bearer = CHARGE_BEARERS[@payload["charge_bearer"]]

        def instructed_amount = money(@payload["instructed_amount"], @payload["instructed_currency_code"])
        def settled_amount = money(@payload["settled_amount"], @payload["settled_currency_code"])

        def instructed_bank = bank(@payload["instructed_fi"])
        def updated_by_bank = bank(@payload["updated_by"])

        def charges
          Array(@payload["charges"]).filter_map do |charge|
            amount = money(charge["amount"], charge["currency_code"])
            next if amount.nil?

            Charge.new(amount:, bank: bank(charge["agent"]))
          end
        end

        # Completion and rejection arrive as a `*_updated` event carrying a terminal
        # status, so the label has to come from the status rather than the type alone.
        def label
          return "Credited to the recipient" if delivered?
          return "Rejected by the bank" if rejected?
          return "Sent via SWIFT" if first? && base_type == "transfer_initiated"
          return "Forwarded to the next bank" if instructed_bank.present? && base_type == "transfer_updated"

          LABELS[base_type] || type.to_s.humanize
        end

        # `is_cover_transfer_event` and the `fi_` prefix usually travel together; show
        # one tag rather than two that say nearly the same thing.
        def leg_tag
          if cover?
            { label: "Cover leg", title: "The bank-to-bank leg that moves the actual funds behind this wire. It doesn't change the payment's status." }
          elsif bank_leg?
            { label: "Bank leg", title: "An update about the bank-to-bank transfer rather than the customer payment." }
          end
        end

        def style
          return "muted" if cover?
          return "error" if rejected?
          return "success" if delivered?

          "pending"
        end

        def icon
          return "check-circle-fill" if delivered?
          return "flag-fill" if rejected?
          return "send-fill" if type == "transfer_initiated"

          "bank-circle"
        end

        private

        def bank(bic)
          return nil if bic.blank?

          Bank.new(bic)
        end

        def money(amount, currency)
          return nil if amount.blank? || currency.blank?

          Money.from_cents(amount, currency)
        end

      end

    end
  end

end
