# frozen_string_literal: true

module Column
  class SweepJob < ApplicationJob
    FLOATING_BALANCE = 6_000_000_00
    queue_as :low
    def perform
      account = ::ColumnService.get("/bank-accounts/#{ColumnService::Accounts::FS_MAIN}")
      balance = account["balances"]["available_amount"]
      difference = balance - FLOATING_BALANCE

      if difference.abs > 200_000_00
        Airbrake.notify("Column::SweepJob > $200,000. Requires human review / processing.")
        return
      end

      idempotency_key = "floating_transfer_#{Time.now.to_i}"

      return unless difference.positive? || difference.negative?

      description = if difference.positive?
                      "HCB-SWEEP: Transfer to SVB (FS Main) to reduce Column balance to #{ApplicationController.helpers.render_money(FLOATING_BALANCE)}"
                    elsif difference.negative?
                      "HCB-SWEEP: Transfer to Column from SVB (FS Main) to increase Column balance to #{ApplicationController.helpers.render_money(FLOATING_BALANCE)}"
                    end

      type = if difference.positive?
               "CREDIT"
             elsif difference.negative?
               "DEBIT"
             end

      event = Event.find(EventMappingEngine::EventIds::SVB_SWEEPS)

      account_number_id = event.column_account_number&.column_id || Rails.application.credentials.dig(:column, ColumnService::ENVIRONMENT, :default_account_number)

      ColumnService.post("/transfers/ach", {
        idempotency_key:,
        amount: difference.abs,
        currency_code: "USD",
        type:,
        entry_class_code: "CCD",
        counterparty: {
          account_number: Rails.application.credentials.svb[:account_number],
          routing_number: Rails.application.credentials.svb[:routing_number],
        },
        description:,
        company_entry_description: "HCB-SWEEP",
        account_number_id:,
        same_day: true,
      }.compact_blank)

    end

  end
end
