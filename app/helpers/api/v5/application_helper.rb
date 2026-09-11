# frozen_string_literal: true

module Api
  module V5
    module ApplicationHelper
      include UsersHelper # for `profile_picture_for`
      include StripeAuthorizationsHelper
      include AdminScopeCheckable
      include ::ApplicationHelper

      attr_reader :current_user, :current_token

      # Renders the standard object envelope and yields an `Api::FieldSet`
      # scoped to what this user may see on this record.
      #
      # Serializers write fields through the yielded emitter rather than
      # through `json`, so attribute-level authorization is deny-by-default:
      # anything the record's policy doesn't list in `visible_attributes` is
      # never emitted. `id` and `object` are always present — a caller that
      # reached this object is allowed to know it exists, and v3's "minimized"
      # shape is exactly these two keys.
      def object_shape(json, record, object_name: nil, created_at: true)
        json.id record.public_id
        json.object object_name || record.model_name.singular

        yield Api::FieldSet.new(json, policy(record).visible_attributes)

        json.created_at record.created_at if created_at
      end

      def pagination_metadata(json)
        json.total_count @total_count
        json.has_more @has_more
      end

      def expand?(key)
        @expand.include?(key)
      end

      # Returns a related object as either expanded or as an "_id" reference.
      # Unlike the bare `json.set!`, this routes through the FieldSet so an
      # association the policy doesn't list is not emitted in either form —
      # an `_id` reference still discloses that the relationship exists.
      def expand_association(f, json, key, record, partial:, as:, locals: {})
        if expand?(key)
          f.nest(key) do
            if record.present?
              json.partial! partial, locals: { as => record }.merge(locals)
            else
              json.nil!
            end
          end
        else
          f.public_send(:"#{key}_id", record&.public_id)
        end
      end

      def expand(*keys)
        before = @expand
        @expand = @expand.dup + keys

        yield
      ensure
        @expand = before
      end

      def transaction_amount(tx, event: nil)
        return tx.amount.cents if !tx.is_a?(HcbCode)

        if tx.outgoing_disbursement? && event == tx.outgoing_disbursement.disbursement.source_event
          return -tx.outgoing_disbursement.disbursement.amount
        elsif tx.outgoing_disbursement? && event == tx.outgoing_disbursement.disbursement.destination_event
          return tx.outgoing_disbursement.disbursement.amount
        end

        return tx.incoming_disbursement.amount if tx.incoming_disbursement?
        return tx.donation.amount if tx.donation?
        return tx.invoice.item_amount if tx.invoice?

        tx.amount.cents
      end

    end
  end
end
