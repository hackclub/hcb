# frozen_string_literal: true

module StripeCardService
  class Nightly
    CARD_FEE_MEMO = "💳 New user card fee"

    def run
      rename_canonical_transaction
    end

    private

    # [@garyhtou] This really should be done via linking the CT to a Stripe Card
    # via an new HCB Code type.
    #
    #   The HCB Code's memo would use a default custom stripe card memo that
    #   supersedes the CT's default memo (from plaid). That default custom
    #   stripe card memo in the HCB Code would be superseded by the CT's
    #   custom memo (if it exists).
    #
    #   Check out HcbCode#memo for more info on how this work.
    def rename_canonical_transaction
      stripe_issuing_card_canonical_transactions_to_rename.find_each(batch_size: 100) do |canonical_transaction|
        # `without_custom_memo` only filters on the canonical transaction, so an
        # organizer's rename that so far only reached the ledger item would be
        # overwritten by this default memo.
        next if canonical_transaction.ledger_item&.custom_memo.present?

        # `custom_memo` is mirrored onto the transaction's ledger item, which
        # caches its `memo` from that copy. `HcbCode#update_custom_memo!` is the
        # only writer that keeps both sides in sync — an `update_all` here would
        # skip every callback and leave the ledger showing the raw bank memo.
        #
        # `safely` keeps one unrenameable transaction from aborting the nightly.
        safely do
          canonical_transaction.local_hcb_code.update_custom_memo!(CARD_FEE_MEMO)
        end
      end
    end

    def stripe_issuing_card_canonical_transactions_to_rename
      CanonicalTransaction.likely_hack_club_bank_issued_cards.without_custom_memo
    end

  end
end
