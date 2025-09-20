# frozen_string_literal: true

module OneTimeJobs
  class BackfillDonationAndFeeCategories
    include Sidekiq::IterableJob
    sidekiq_options(queue: :low, retry: false)

    RELEVANT_CODES = [
      TransactionGroupingEngine::Calculate::HcbCode::INVOICE_CODE,
      TransactionGroupingEngine::Calculate::HcbCode::DONATION_CODE,
      TransactionGroupingEngine::Calculate::HcbCode::STRIPE_SERVICE_FEE_CODE,
      TransactionGroupingEngine::Calculate::HcbCode::BANK_FEE_CODE,
      TransactionGroupingEngine::Calculate::HcbCode::OUTGOING_FEE_REIMBURSEMENT_CODE,
      TransactionGroupingEngine::Calculate::HcbCode::FEE_REVENUE_CODE
    ].freeze

    def build_enumerator(cursor:)
      # Constructs a query that narrows down the `hcb_codes` table to just the
      # types we are interested in backfilling. This can be done quite optimally
      # within PG as the optimizer can leverage the b-tree for prefix patterns.
      # https://www.postgresql.org/docs/current/indexes-types.html#INDEXES-TYPES-BTREE
      relation =
        RELEVANT_CODES
        .map { |code| HcbCode.where("hcb_code like ?", "HCB-#{code}-%") }
        .inject(&:or)

      active_record_records_enumerator(relation, cursor:)
    end

    def each_iteration(hcb_code)
      slug =
        if hcb_code.invoice? || hcb_code.donation?
          "donations"
        else
          EventMappingEngine::Map::HcbCodes::Short.category_slug_for_hcb_code(hcb_code)
        end

      return unless slug

      assignment_strategy = "automatic"

      hcb_code.canonical_pending_transactions.each do |cpt|
        TransactionCategoryService.new(model: cpt).set!(slug:, assignment_strategy:)
      end

      hcb_code.canonical_transactions.each do |ct|
        TransactionCategoryService.new(model: ct).set!(slug:, assignment_strategy:)
      end
    end

  end
end
