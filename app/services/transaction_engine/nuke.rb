# frozen_string_literal: true

module TransactionEngine
  class Nuke
    def run
      return unless Rails.env.development?

      Fee.delete_all
      CanonicalEventMapping.delete_all

      CanonicalPendingDeclinedMapping.delete_all
      CanonicalPendingSettledMapping.delete_all

      CanonicalHashedMapping.delete_all

      CanonicalTransaction.delete_all

      HashedTransaction.delete_all

      RawCsvTransaction.delete_all
      RawPlaidTransaction.delete_all
      RawEmburseTransaction.delete_all
      RawStripeTransaction.delete_all
      RawIncreaseTransaction.delete_all
      RawColumnTransaction.delete_all

      true
    end

  end
end
