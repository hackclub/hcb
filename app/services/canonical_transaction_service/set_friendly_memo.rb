# frozen_string_literal: true

module CanonicalTransactionService
  class SetFriendlyMemo
    def initialize(canonical_transaction_id:, friendly_memo:)
      @canonical_transaction_id = canonical_transaction_id
      @friendly_memo = friendly_memo
    end

    def run
      canonical_transaction.friendly_memo = @friendly_memo.blank? ? nil : @friendly_memo.strip
      canonical_transaction.save!
    end

    private

    def canonical_transaction
      @canonical_transaction ||= CanonicalTransaction.find(@canonical_transaction_id)
    end

  end
end
