# frozen_string_literal: true

module Api
  module Models
    # Keep the existing HcbCode-derived chg_ IDs and associations for v3 clients.
    # Card-charge details come from the new engine's Ledger::Item and CardCharge,
    # rather than reconstructing the charge from legacy canonical transactions.
    class CardCharge < HcbCode
      # Changes the Public ID Prefix to `chg` (instead of `txn` set by HcbCode).
      set_public_id_prefix :chg

      # Give Hashid a new pepper so that the public IDs look different than
      # the ones for transactions (HcbCodes).
      hashid_config pepper: "api_card_charge", salt: ""

      # Set the default scope to HCB-600-* hcb codes (card charges).
      default_scope { where("hcb_code LIKE 'HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::STRIPE_CARD_CODE}-%'") }

      scope :with_details, -> {
        preload(ledger_item: { linked_object: [:raw_pending_stripe_transaction, :raw_stripe_transactions] })
      }

      def status
        ledger_item&.status
      end

      def ledger_card_charge
        ledger_item&.linked_object if ledger_item&.linked_object_type == "CardCharge"
      end

      def merchant_data
        ledger_card_charge&.stripe_merchant_data
      end

      delegate :authorization_method, :decline_reason, to: :ledger_card_charge, allow_nil: true

      # Only allow modification from HcbCode.
      def readonly?
        true
      end

      def create_or_update
        raise ActiveRecord::ReadOnlyRecord
      end

      before_create { raise ActiveRecord::ReadOnlyRecord }
      before_destroy { raise ActiveRecord::ReadOnlyRecord }
      before_save { raise ActiveRecord::ReadOnlyRecord }
      before_update { raise ActiveRecord::ReadOnlyRecord }

    end
  end
end
