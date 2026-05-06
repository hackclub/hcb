# frozen_string_literal: true

module Api
  module V4
    module ApplicationHelper
      include UsersHelper # for `profile_picture_for`
      include StripeAuthorizationsHelper

      attr_reader :current_user, :current_token

      def object_shape(json, object, object_name: nil, created_at: true, &block)
        json.id object.public_id
        json.object object_name || object.model_name.singular
        block.call
        json.created_at object.created_at if created_at
      end

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

      def shares_org_with?(user)
        return false if current_user.nil? || user.nil?

        # Events that the current user has access to view
        @current_user_event_ids ||= current_user.readable_events.pluck(:id)
        return false if @current_user_event_ids.empty?

        # Does it overlap with events that the user has organizer positions in?
        # We're explicitly checking for OPs instead of access because your email
        # is not visible just because you have (read) access to an org. The
        # emails addresses of organizers in a parent org is not visible to the
        # organizers of a child org.
        @current_user_event_ids.to_set.intersect?(user.organizer_positions.pluck(:event_id))
      end

      def expand_pii(override_if: false)
        yield if (current_token&.scopes&.include?("pii") && current_user&.admin?) || override_if
      end

    end
  end
end
