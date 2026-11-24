# frozen_string_literal: true

module Maintenance
  # Donations routed through a clearing organization (HCB Clearinghouse,
  # Benevity Clearinghouse, Unallocated Donations) reach the organization
  # they're for as a transfer, so the receiving side was categorized as an
  # internal transfer and no longer counts towards that organization's
  # revenue. Recategorize the receiving side as a donation. The clearing
  # organization's side stays an internal transfer, since it only passes the
  # money along. Anything an organization already recategorized is left alone.
  class RecategorizeClearinghouseTransfersAsDonationsTask < MaintenanceTasks::Task
    # Comma-separated ids of the clearing organizations, e.g. "123, 456, 789".
    attribute :source_event_ids, :string
    validates :source_event_ids, format: { with: /\A\s*\d+(\s*,\s*\d+)*\s*\z/, message: "must be comma-separated event ids" }

    def collection
      Disbursement
        .where(source_event_id: source_event_ids.split(",").map(&:to_i), source_subledger_id: nil, destination_subledger_id: nil)
        .where(transfer_type: [nil, "transfer"])
    end

    def process(disbursement)
      if replaceable?(disbursement.destination_transaction_category)
        disbursement.update!(destination_transaction_category: donations_category)
      end

      [CanonicalTransaction, CanonicalPendingTransaction].each do |model|
        model.where(hcb_code: disbursement.incoming_hcb_code).find_each do |transaction|
          next unless replaceable?(transaction.category)

          TransactionCategoryService
            .new(model: transaction)
            .set!(slug: donations_category.slug, assignment_strategy: transaction.category_mapping&.assignment_strategy || "automatic")
        end
      end
    end

    private

    def replaceable?(category)
      category.nil? || category.slug == Event::StatementOfActivity::INTERNAL_TRANSFER_SLUG
    end

    def donations_category
      @donations_category ||= TransactionCategory.find_or_create_by!(slug: "donations")
    end

  end
end
