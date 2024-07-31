# frozen_string_literal: true

require "csv"

module ExportService
  class Csv
    BATCH_SIZE = 1000

    def initialize(event_id:, public_only: false)
      @event_id = event_id
      @public_only = public_only
    end

    def run
      Enumerator.new do |y|
        y << header.to_s

        event.canonical_transactions.order("date desc").each do |ct|
          y << row(ct).to_s
        end
      end
    end

    private

    def event
      @event ||= Event.find(@event_id)
    end

    def header
      ::CSV::Row.new(headers, ["date", "memo", "amount_cents", "tags", "comments"], true)
    end

    def row(ct)
      ::CSV::Row.new(
        headers,
        [
          ct.date,
          ct.local_hcb_code.memo,
          @public_only && ct.likely_account_verification_related? ? 0 : ct.amount_cents,
          ct.local_hcb_code.tags.filter { |tag| tag.event_id == @event_id }.pluck(:label).join(", "),
          @public_only ? "" : ct.local_hcb_code.comments.not_admin_only.pluck(:content).join("\n\n")
        ]
      )
    end

    def headers
      [:date, :memo, :amount_cents, :tags, :comments]
    end

  end
end
