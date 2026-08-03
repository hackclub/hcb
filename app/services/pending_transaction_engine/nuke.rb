# frozen_string_literal: true

module PendingTransactionEngine
  class Nuke
    def run
      return unless Rails.env.development?

      CanonicalPendingEventMapping.delete_all
      CanonicalPendingTransaction.delete_all
      RawPendingStripeTransaction.delete_all

      true
    end

  end
end
