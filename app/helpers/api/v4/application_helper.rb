# frozen_string_literal: true

module Api
  module V4
    module ApplicationHelper
      include UsersHelper # for `profile_picture_for`
      include StripeAuthorizationsHelper

      attr_reader :current_user, :current_token

      def pagination_metadata(json)
        json.total_count @total_count
        json.has_more @has_more
      end

      def paginate_hcb_codes(hcb_codes)
        limit = params[:limit]&.to_i || 25
        return render json: { error: "invalid_operation", messages: "Limit is capped at 100. '#{params[:limit]}' is invalid." }, status: :bad_request if limit > 100

        start_index = if params[:after]
                        index = hcb_codes.index { |hcb_code| hcb_code.public_id == params[:after] }
                        return render json: { error: "invalid_operation", messages: "After parameter '#{params[:after]}' not found" }, status: :bad_request if index.nil?

                        index + 1
                      else
                        0
                      end
        @has_more = hcb_codes.length > start_index + limit

        hcb_codes.slice(start_index, limit)
      end

      def transaction_amount(tx, event: nil)
        return tx.amount.cents if !tx.is_a?(HcbCode)

        return tx.outgoing_disbursement.amount if tx.outgoing_disbursement?
        return tx.incoming_disbursement.amount if tx.incoming_disbursement?
        return tx.donation.amount if tx.donation?
        return tx.invoice.item_amount if tx.invoice?

        tx.amount.cents
      end

      def expand?(key)
        @expand.include?(key)
      end

      def expand(*keys)
        before = @expand
        @expand = @expand.dup + keys

        yield
      ensure
        @expand = before
      end

      def expand_pii(override_if: false)
        yield if (current_token&.scopes&.include?("pii") && current_user&.admin?) || override_if
      end

    end
  end
end
