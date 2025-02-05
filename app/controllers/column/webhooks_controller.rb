# frozen_string_literal: true

module Column
  class WebhooksController < ActionController::Base
    skip_before_action :verify_authenticity_token

    before_action :verify_signature

    def webhook
      @object = params[:data]
      type = params[:type]
      if type == "ach.incoming_transfer.scheduled"
        handle_ach_incoming_transfer_scheduled
      elsif type == "ach.outgoing_transfer.returned"
        handle_ach_outgoing_transfer_returned
      elsif type.start_with?("check.incoming_debit")
        handle_outgoing_check_update
      end
    rescue => e
      notify_airbrake(e)
    ensure
      head :ok
    end

    private

    def handle_ach_incoming_transfer_scheduled
      return if @object[:type].downcase == "credit" || @object[:amount] <= 100 # Allow incoming ACH credits and small debits

      account_number = AccountNumber.find_by(column_id: @object[:account_number_id])

      return if account_number.nil? # Allow debits to non-HCB-managed account numbers

      if account_number.deposit_only?
        ColumnService.return_ach(@object[:id], with: ColumnService::AchCodes::STOP_PAYMENT)
      elsif account_number.event.balance_available_v2_cents < @object[:amount]
        ColumnService.return_ach(@object[:id], with: ColumnService::AchCodes::INSUFFICIENT_BALANCE)
      end

      # at this point, the ACH is approved!
    end

    def handle_ach_outgoing_transfer_returned
      AchTransfer.find_by(column_id: @object[:id])&.mark_failed!(reason: @object[:return_details].pick(:description)&.gsub(/\(trace #: \d+\)\Z/, "")&.strip)
    end

    def handle_swift_outgoing_transfer_returned
      Wire.find_by(column_id: @object[:id])&.mark_failed!(@object[:return_details].pick(:description)&.gsub(/\(trace #: \d+\)\Z/, "")&.strip)
    end

    def handle_outgoing_check_update
      check = IncreaseCheck.find_by(column_id: @object[:id])

      check&.update!(
        column_object: @object,
        check_number: @object[:check_number],
        column_status: @object[:status],
        column_delivery_status: @object[:delivery_status],
      )
    end

    def verify_signature
      signature_valid = ActiveSupport::SecurityUtils.secure_compare(
        OpenSSL::HMAC.hexdigest(
          "SHA256",
          Rails.application.credentials.column.dig(ColumnService::ENVIRONMENT, :webhook_secret),
          request.body.read
        ),
        request.headers["Column-Signature"]
      )

      unless signature_valid
        head :bad_request
      end
    end

  end
end
