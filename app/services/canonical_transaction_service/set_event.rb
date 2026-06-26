# frozen_string_literal: true

module CanonicalTransactionService
  class SetEvent
    def initialize(canonical_transaction_id:, event_id:, user:)
      @canonical_transaction_id = canonical_transaction_id
      @event_id = event_id
      @user = user
    end

    def run
      ActiveRecord::Base.transaction do
        canonical_transaction.canonical_event_mapping&.destroy!

        canonical_event_mapping = CanonicalEventMapping.create!(attrs) if event

        ::SystemEventService::Write::SettledTransactionMapped.new(
          canonical_transaction:,
          canonical_event_mapping:,
          user: @user
        ).run
      end

      canonical_transaction
    end

    private

    def event
      @event ||= ::Cartel.find_by(id: @event_id)
    end

    def attrs
      {
        canonical_transaction_id: canonical_transaction.id,
        event_id: event.try(:id),
        user_id: @user.try(:id)
      }
    end

    def canonical_transaction
      @canonical_transaction ||= CanonicalTransaction.find(@canonical_transaction_id)
    end

  end
end
