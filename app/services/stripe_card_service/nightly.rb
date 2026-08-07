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
        # Renaming writes the whole HCB code group, while `without_custom_memo`
        # only filters on this one transaction. Skip the group entirely if anything
        # in it already carries an organizer's memo — this default would erase it.
        # `HcbCode#custom_memo` only reads the first transaction, so check them all.
        hcb_code = canonical_transaction.local_hcb_code
        next if hcb_code&.canonical_transactions&.with_custom_memo&.exists? ||
                hcb_code&.canonical_pending_transactions&.with_custom_memo&.exists? ||
                canonical_transaction.ledger_item&.custom_memo.present?

        # `custom_memo` is mirrored onto the transaction's ledger item, which
        # caches its `memo` from that copy. `HcbCode#update_custom_memo!` is the
        # only writer that keeps both sides in sync — an `update_all` here would
        # skip every callback and leave the ledger showing the raw bank memo.
        #
        # `safely` keeps one unrenameable transaction from aborting the nightly.
        safely do
          if hcb_code
            hcb_code.update_custom_memo!(CARD_FEE_MEMO)
          elsif (ledger_item = canonical_transaction.ledger_item)
            ledger_item.update_custom_memo!(CARD_FEE_MEMO)
          else
            canonical_transaction.update!(custom_memo: CARD_FEE_MEMO)
          end
        end
      end
    end

    def stripe_issuing_card_canonical_transactions_to_rename
      CanonicalTransaction.likely_hack_club_bank_issued_cards.without_custom_memo
    end

  end
end
