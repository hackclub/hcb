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
        wire_transfer
        wise_transfer
        check_deposit
        reimbursed_expense
        hcb_fee
      ].freeze

      # "transaction" is either an HCB Code or a Ledger Item
      when_expanded do
        expose :ledger_item_id, documentation: { type: "string" }, if: ->(transaction, options) { options[:ledger] } do |transaction, options|
          transaction.ledger_item&.public_id
        end
        expose :amount_cents, documentation: { type: "integer" } do |transaction, options|
          org = options[:org]

          # By default, linked objects use the HcbCode#amount_cents method.
          # However, for Disbursements, this will always result in an
          # amount_cents of 0 (zero) since there are two equal, by opposite,
          # Canonical Transactions. Therefore, for the API, we are overriding the
          # default amount_cents exposure defined in the LinkedObjectBase.

          # should be removed post-migration
          if transaction.outgoing_disbursement? && org == transaction.outgoing_disbursement.disbursement.source_event &&
             !(transaction.outgoing_disbursement.disbursement.source_subledger_id && transaction.outgoing_disbursement.disbursement.destination_subledger_id.nil?) # disbursements with a source_subledger_id and no destination_subledger_id are returned card grants
            next -transaction.outgoing_disbursement.disbursement.amount
          elsif transaction.outgoing_disbursement?
            next transaction.outgoing_disbursement.disbursement.amount
          end

          next transaction.incoming_disbursement.amount if transaction.incoming_disbursement?
          next transaction.outgoing_disbursement.amount if transaction.outgoing_disbursement?
          next transaction.donation.amount if transaction.donation?
          next transaction.invoice.item_amount if transaction.invoice?
          next -transaction.ach_transfer.amount if transaction.ach_transfer?
          next 0 if transaction.likely_account_verification_related?

          transaction.amount_cents
        end
        expose :memo do |transaction, options|
          transaction.memo(event: options[:org])
        end
        format_as_date do
          expose :date
        end

        # This uses the `linked_object_type` method defined below
        expose :linked_object_type, as: :type, documentation: {
          values: LINKED_OBJECT_TYPES
        }
        expose :pending, documentation: { type: "boolean" } do |transaction, options|
          transaction.canonical_transactions.empty? && transaction.canonical_pending_transactions.none? { |pt| pt.fronted? }
        end

        expose :receipts do
          expose :count, documentation: { type: "integer" } do |transaction, options|
            transaction.receipts.size
          end
          expose :missing, documentation: { type: "boolean" } do |transaction, options|
            # This logic really needs to be moved inside the HcbCode model
            [:card_charge, :card_force_capture].include?(transaction.type) &&
              !transaction.no_or_lost_receipt? &&
              transaction.receipts.none?
          end
        end

        expose :comments do
          expose :count, documentation: { type: "integer" } do |transaction, options|
            transaction.not_admin_only_comments_count
          end
        end
      end

      expose_associated Organization do |transaction, options|
        transaction.event
      end

      expose_associated User do |transaction, options|
        transaction.author
      end

      expose_associated Tag, documentation: { type: Tag, is_array: true }, as: :tags do |transaction, options|
        transaction.tags
      end

      when_showing LinkedObjectBase::API_LINKED_OBJECT_TYPE do
        [
          {
            entity: Entities::CardCharge,
            hcb_method: ->(transaction) { Models::CardCharge.find_by(id: transaction.local_hcb_code&.id) },
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
            hcb_method: ->(transaction) do
              if transaction.outgoing_disbursement?
                transaction.outgoing_disbursement.disbursement
              else
                transaction.incoming_disbursement.disbursement
              end
            end
          },
          {
            entity: Entities::WireTransfer,
            hcb_method: :wire
          },
          {
            entity: Entities::WiseTransfer,
            hcb_method: :wise_transfer
          },
          {
            entity: Entities::CheckDeposit,
            hcb_method: :check_deposit
          },
          {
            entity: Entities::ReimbursedExpense,
            hcb_method: :reimbursement_expense_payout
          },
          {
            entity: Entities::HcbFee,
            hcb_method: :bank_fee
          },
        ].each do |linked_type|
          entity = linked_type[:entity]
          method = linked_type[:hcb_method]
          type = entity.object_type

          expose type, if: ->(transaction, options) {
            obj_type = linked_object_type(transaction.type).to_s
            self.class.should_show?(entity) && type == obj_type
          }, documentation: {
            type: entity
          } do |transaction, options|
            linked_objects = if method.is_a? Proc
                               method.call(transaction)
                             else
                               transaction.public_send(method)
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
        when :wire # rename "wire" to "wire_transfer"
          :wire_transfer
        when :reimbursement_expense_payout # rename to "reimbursed_expense"
          :reimbursed_expense
        when :bank_fee # rename to "hcb_fee"
          :hcb_fee
        else
          type
        end
      end

    end
  end
end
