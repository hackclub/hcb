# frozen_string_literal: true

module Maintenance
  # The HCB Clearinghouse only passes donations along to the organizations
  # they're for, which count them as donations (see
  # RecategorizeClearinghouseTransfersAsDonationsTask). Counting them again as
  # the Clearinghouse's own revenue would double them, so recategorize money
  # coming into the Clearinghouse as an internal transfer. Only uncategorized
  # transactions and ones categorized as donations are changed.
  class RecategorizeClearinghouseIncomeAsInternalTransfersTask < MaintenanceTasks::Task
    REPLACEABLE_SLUGS = ["donations"].freeze

    attribute :clearinghouse_event_id, :integer
    validates :clearinghouse_event_id, presence: true

    def collection
      CanonicalTransaction
        .joins(:canonical_event_mapping)
        .where(canonical_event_mapping: { event_id: clearinghouse_event_id, subledger_id: nil })
        .where("amount_cents > 0")
    end

    def process(canonical_transaction)
      [canonical_transaction, canonical_transaction.canonical_pending_transaction].compact.each do |transaction|
        next unless transaction.category.nil? || transaction.category.slug.in?(REPLACEABLE_SLUGS)

        TransactionCategoryService
          .new(model: transaction)
          .set!(slug: Event::StatementOfActivity::INTERNAL_TRANSFER_SLUG, assignment_strategy: transaction.category_mapping&.assignment_strategy || "automatic")
      end
    end

  end
end
