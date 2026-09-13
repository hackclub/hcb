# frozen_string_literal: true

module Api
  module V5
    # The mechanics every outbound-transfer create shares. v4 repeats the
    # sudo-mode guard verbatim in three controllers and the receipt attachment
    # in three more; a copy that drifts is how one of them ends up without the
    # threshold check.
    module TransferCreation
      extend ActiveSupport::Concern

      private

      # Transfers above the sudo-mode threshold require re-authentication,
      # which an API token cannot perform — so they are refused outright rather
      # than silently created without the check a browser session would get.
      def refuse_above_sudo_threshold!(amount_cents, noun:)
        return false if amount_cents.to_i <= SudoModeHandler::THRESHOLD_CENTS

        threshold = ApplicationController.helpers.render_money(SudoModeHandler::THRESHOLD_CENTS)
        render json: {
          error: "invalid_operation",
          messages: ["#{noun} above the sudo mode threshold of #{threshold} are not allowed via the API."]
        }, status: :bad_request

        true
      end

      # Transfer creates accept an optional receipt in the same request.
      def attach_receipt!(receiptable, file)
        return if file.blank?

        ::ReceiptService::Create.new(
          uploader: current_user,
          attachments: file,
          upload_method: :api,
          receiptable:
        ).run!
      end

      # Organizations are addressable by public id or slug throughout v5.
      def find_organization!(param)
        Event.find_by_public_id(param) || Event.friendly.find(param)
      end

    end
  end
end
