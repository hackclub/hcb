# frozen_string_literal: true

require "json"

module ExportService
  class Json
    def initialize(event_id:, public_only: false)
      @event_id = event_id
      @public_only = public_only
    end

    # NOTE: technically not streaming at this time
    def run
      event.canonical_transactions.order("date desc").map do |ct|
        row(ct)
      end.to_json
    end

    private

    def event
      @event ||= Event.find(@event_id)
    end

    def row(ct)
      {
        date: ct.date,
        memo: ct.local_hcb_code.memo,
        amount_cents: @public_only && ct.likely_account_verification_related? ? 0 : ct.amount_cents,
        tags: ct.local_hcb_code.tags.filter { |tag| tag.event_id == @event_id }.pluck(:label).join(", "),
        comments: @public_only ? [] : ct.local_hcb_code.comments.not_admin_only.pluck(:content)
      }
    end

  end
end
