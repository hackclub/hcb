# frozen_string_literal: true

module Api
  module Entities
    class Transaction < Base
      LINKED_OBJECT_TYPES = %w[
        invoice
        donation
        ach_transfer
        check
        transfer
        bank_account_transaction
        card_charge
      ].freeze

      when_expanded do
        expose :amount_cents, documentation: { type: "integer" } do |hcb_code, options|
          org = options[:org]

          # By default, linked objects use the HcbCode#amount_cents method.
          # However, for Disbursements, this will always result in an
          # amount_cents of 0 (zero) since there are two equal, by opposite,
          # Canonical Transactions. Therefore, for the API, we are overriding the
          # default amount_cents exposure defined in the LinkedObjectBase.
          if hcb_code.disbursement? && org == hcb_code.disbursement.source_event &&
             !(hcb_code.disbursement.source_subledger_id && hcb_code.disbursement.destination_subledger_id.nil?) # disbursements with a source_subledger_id and no destination_subledger_id are returned card grants
            next -hcb_code.disbursement.amount
          elsif hcb_code.disbursement?
            next hcb_code.disbursement.amount
          end
          next hcb_code.donation.amount if hcb_code.donation?
          next hcb_code.invoice.item_amount if hcb_code.invoice?
          next -hcb_code.ach_transfer.amount if hcb_code.ach_transfer?
          next 0 if hcb_code.likely_account_verification_related?

          hcb_code.amount_cents
        end
        expose :memo do |hcb_code, options|
          hcb_code.memo(event: options[:org])
        end
        format_as_date do
          expose :date
        end

        # This uses the `linked_object_type` method defined below
        expose :linked_object_type, as: :type, documentation: {
          values: LINKED_OBJECT_TYPES
        }
        expose :pending, documentation: { type: "boolean" } do |hcb_code, options|
          if hcb_code.event.can_front_balance?
            next hcb_code.canonical_transactions.empty? && hcb_code.canonical_pending_transactions.none? { |pt| pt.fronted? }
          end

          hcb_code.canonical_transactions.empty?
        end

        expose :receipts do
          expose :count, documentation: { type: "integer" } do |hcb_code, options|
            hcb_code.receipts.size
          end
          expose :missing, documentation: { type: "boolean" } do |hcb_code, options|
            # This logic really needs to be moved inside the HcbCode model
            hcb_code.type == :card_charge &&
              !hcb_code.no_or_lost_receipt? &&
              hcb_code.receipts.none?
          end
        end

        expose :comments do
          expose :count, documentation: { type: "integer" } do |hcb_code, options|
            hcb_code.not_admin_only_comments_count
          end
        end
      end

      expose_associated Organization do |hcb_code, options|
        hcb_code.event
      end

      expose_associated Tag, documentation: { type: Tag, is_array: true }, as: :tags do |hcb_code, options|
        hcb_code.tags
      end

      when_showing LinkedObjectBase::API_LINKED_OBJECT_TYPE do
        [
          {
            entity: Entities::CardCharge,
            # Convert the HcbCode to it's equivalent CardCharge.
            hcb_method: ->(hcb_code) { Models::CardCharge.find(hcb_code.id) },
          },
          {
            entity: Entities::AchTransfer,
            hcb_method: :ach_transfer
          },
          {
            entity: Entities::Check,
            hcb_method: :check
          },
          {
            entity: Entities::Donation,
            hcb_method: :donation
          },
          {
            entity: Entities::Invoice,
            hcb_method: :invoice
          },
          {
            entity: Entities::Transfer,
            hcb_method: :disbursement
          },
        ].each do |linked_type|
          entity = linked_type[:entity]
          method = linked_type[:hcb_method]
          type = entity.object_type

          expose type, if: ->(hcb_code, options) {
            obj_type = linked_object_type(hcb_code.type).to_s
            self.class.should_show?(entity) && type == obj_type
          }, documentation: {
            type: entity
          } do |hcb_code, options|
            linked_objects = if method.is_a? Proc
                               method.call(hcb_code)
                             else
                               hcb_code.public_send(method)
                             end
            entity.represent(linked_objects, options_hide([self, Organization]))
          end

        end
      end

      protected

      def linked_object_type(type = object.type)
        # some of the symbols returned by `object.type` needs to be transformed
        # to match the public representation of linked object types defined by
        # the constant LINKED_OBJECT_TYPES
        case type
        when :ach # rename "ach" to "ach_transfer"
          :ach_transfer
        when :disbursement # rename "disbursement" to "transfer"
          :transfer
        when :unknown # rename "unknown" to "bank_account_transaction"
          :bank_account_transaction
        else
          type
        end
      end

    end
  end
end
