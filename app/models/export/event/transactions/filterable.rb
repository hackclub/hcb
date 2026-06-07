# frozen_string_literal: true

module Export::Event::Transactions::Filterable
  FILTER_PARAMS = %i[tag_id user_id transaction_type direction minimum_amount maximum_amount missing_receipts category_slug merchant_id start_date end_date].freeze

  def self.included(base)
    base.store_accessor :parameters, *FILTER_PARAMS
  end

  private

  # Applies active filters to +base_scope+. When +check_dates+ is false,
  # date-only filters use a simple SQL path (preserving CSV's original behaviour).
  def filter_transactions(base_scope, check_dates: true)
    return apply_date_filters(base_scope) if no_filters_applied?(check_dates:)

    engine = TransactionGroupingEngine::Transaction::All.new(
      event_id:,
      tag_id:,
      expenses: direction == "expenses",
      revenue: direction == "revenue",
      minimum_amount: minimum_amount ? Money.from_amount(minimum_amount.to_f) : nil,
      maximum_amount: maximum_amount ? Money.from_amount(maximum_amount.to_f) : nil,
      start_date:,
      end_date:,
      user: user_id ? User.find_by(id: user_id) : nil,
      missing_receipts: [true, "true"].include?(missing_receipts),
      category: category_slug ? TransactionCategory.find_by(slug: category_slug) : nil,
      merchant: merchant_id,
      order_by: :date
    )

    ct_ids = engine.run.flat_map(&:canonical_transaction_ids)
    txs = CanonicalTransaction.includes(local_hcb_code: [:tags, :comments])
                              .where(id: ct_ids)
                              .order("date desc, id desc")

    transaction_type.present? ? filter_by_type(txs) : txs
  end

  def apply_date_filters(scope)
    scope = scope.where("date >= ?", start_date) if start_date.present?
    scope = scope.where("date <= ?", end_date) if end_date.present?
    scope
  end

  def no_filters_applied?(check_dates: true)
    base = tag_id.blank? && user_id.blank? && transaction_type.blank? &&
           direction.blank? && minimum_amount.blank? && maximum_amount.blank? &&
           missing_receipts.blank? && category_slug.blank? && merchant_id.blank?
    check_dates ? base && start_date.blank? && end_date.blank? : base
  end

  def filter_by_type(txs)
    scope_method = {
      "card_charge" => :card_charge, "ach" => :ach, "check" => :check,
      "other" => :other, "paypal" => :paypal, "wire" => :wire,
      "transfer" => :transfer, "hcb_transfer" => :hcb_transfer
    }[transaction_type]
    scope_method ? txs.public_send(scope_method) : txs
  end
end
