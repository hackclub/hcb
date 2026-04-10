# frozen_string_literal: true

module Api
  module V4
    module ApplicationHelper
      include UsersHelper # for `profile_picture_for`
      include StripeAuthorizationsHelper

      attr_reader :current_user, :current_token

      def json_object(json, object)
        json.id object.public_id
        json.object object.model_name.element
        json.created_at object.created_at
      end

      def pagination_metadata(json)
        json.total_count @total_count
        json.has_more @has_more
      end

      def transaction_amount(tx, event: nil)
        return tx.amount.cents if !tx.is_a?(HcbCode)

        if tx.outgoing_disbursement? && event == tx.outgoing_disbursement.disbursement.source_event
          return -tx.outgoing_disbursement.disbursement.amount
        elsif tx.outgoing_disbursement? && event == tx.outgoing_disbursement.disbursement.destination_event
          return tx.outgoing_disbursement.disbursement.amount # incoming that needs a backfill
        end

        # return tx.outgoing_disbursement.amount if tx.outgoing_disbursement?
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
