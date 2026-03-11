# frozen_string_literal: true

module Api
  module Models
    # Card Charges are not an actual linked object within the transaction
    # engine. It's pretty messy. In the TX engine, they're represented with:
    # - RawPendingStripeTransaction
    # - RawStripeTransaction
    #
    # and accessed via HcbCode using:
    # - CanonicalTransaction
    # - CanonicalPendingTransaction
    #
    # There isn't a great Model for representing Card Charges. However, since
    # HcbCodes have easy access to all the card charge data, we'll be using
    # HcbCodes to represent Card Charges in the API.
    #
    # This class is an ActiveRecord model and inherits from HcbCode. This
    # definitely feels pretty hacky, but it seems to be the simplest way to give
    # card charges their own public ID and to have "stricter" types. I've tried
    # my best to prevent database modifications by this CardCharge model.
    # ~ @garyhtou
    class CardCharge < HcbCode
      # Changes the Public ID Prefix to `chg` (instead of `txn` set by HcbCode).
      set_public_id_prefix :chg

      # Give Hashid a new pepper so that the public IDs look different than
      # the ones for transactions (HcbCodes).
      hashid_config pepper: "api_card_charge"

      # Set the default scope to HCB-600-* hcb codes (card charges).
      default_scope { where("hcb_code LIKE 'HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::STRIPE_CARD_CODE}-%'") }

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
