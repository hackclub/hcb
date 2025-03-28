# frozen_string_literal: true

module Column
  class SweepJob < ApplicationJob
    MINIMUM_AVG_BALANCE = 5_000_000_00 # 5 mil
    FLOATING_BALANCE = MINIMUM_AVG_BALANCE + 500_000_00 # 5.5 mil
    queue_as :low

    def perform
      account = ::ColumnService.get("/bank-accounts/#{ColumnService::Accounts::FS_MAIN}")
      balance = account["balances"]["available_amount"]
      difference = balance - FLOATING_BALANCE

      if balance < MINIMUM_AVG_BALANCE
        Airbrake.notify("Column available balance under #{MINIMUM_AVG_BALANCE}")
      end

      if difference.abs > 200_000_00 && difference.negative? # if negative, it is a transfer from SVB (FS Main) to Column
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

      account_number_id = event.column_account_number&.column_id || Credentials.fetch(:COLUMN, ColumnService::ENVIRONMENT, :DEFAULT_ACCOUNT_NUMBER)

      ColumnService.post("/transfers/ach", {
        idempotency_key:,
        amount: difference.abs,
        currency_code: "USD",
        type:,
        entry_class_code: "CCD",
        counterparty: {
          account_number: Credentials.fetch(:SVB_ACCOUNT_NUMBER),
          routing_number: Credentials.fetch(:SVB_ACCOUNT_NUMBER),
        },
        description:,
        company_entry_description: "HCB-SWEEP",
        account_number_id:,
        same_day: true,
      }.compact_blank)

    end

  end
end
