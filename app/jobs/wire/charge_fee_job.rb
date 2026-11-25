# frozen_string_literal: true

class Wire
  class ChargeFeeJob < ApplicationJob
    queue_as :default
    sidekiq_options retry: false

    def perform(wire, requested_by:)
      begin
        disbursement = DisbursementService::Create.new(
          name: "Low-value wire transfer fee",
          destination_event_id: EventMappingEngine::EventIds::HACK_CLUB_BANK,
          source_event_id: wire.event.id,
          amount: Wire::SMALL_WIRE_FEE_AMOUNT_CENTS / 100.0,
          requested_by_id: requested_by.id,
          fronted: wire.event.plan.front_disbursements_enabled?,
          transfer_type: "transfer"
        ).run
      rescue => e
        Rails.error.report(e)
        wire.local_hcb_code.comments.create!(
          content: "Couldn't charge the #{fee} fee for this wire automatically (#{e.message}). It needs to be charged by hand.",
          user: User.system_user,
          admin_only: true
        )
        return
      end

      disbursement.comments.create!(
        content: "This #{fee} fee covers the cost of sending a wire under #{ActiveSupport::NumberHelper.number_to_currency(Wire::MINIMUM_AMOUNT_CENTS / 100.0)}: #{Rails.application.routes.url_helpers.ledger_item_url(wire.ledger_item)}",
        user: requested_by
      )
    end

    private

    def fee
      ActiveSupport::NumberHelper.number_to_currency(Wire::SMALL_WIRE_FEE_AMOUNT_CENTS / 100.0)
    end

  end

end
