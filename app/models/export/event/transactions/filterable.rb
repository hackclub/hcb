# frozen_string_literal: true

class Export
  module Event
    module Transactions
      module Filterable
        def async?
          if no_filters_applied?
            event.canonical_transactions.size > 300
          else
            transactions.size > 300
          end
        end

        private

        def transactions
          return fallback_transactions if no_filters_applied?

          engine = TransactionGroupingEngine::Transaction::All.new(
            event_id: event_id,
            search: search,
            tag_id: tag_id,
            expenses: direction == "expenses",
            revenue: direction == "revenue",
            minimum_amount: minimum_amount ? Money.new(minimum_amount.to_i) : nil,
            maximum_amount: maximum_amount ? Money.new(maximum_amount.to_i) : nil,
            start_date: start_date,
            end_date: end_date,
            user: user_id ? User.find_by(id: user_id) : nil,
            missing_receipts: [true, "true"].include?(missing_receipts),
            category: category_slug ? TransactionCategory.find_by(slug: category_slug) : nil,
            merchant: merchant_id,
            order_by: :date
          )

          ct_ids = engine.run.flat_map(&:canonical_transaction_ids)
          canonical_txs = CanonicalTransaction.includes(local_hcb_code: [:tags, :comments])
                                              .where(id: ct_ids)
                                              .order("date desc, id desc")

          canonical_txs = filter_by_type(canonical_txs) if transaction_type.present?
          canonical_txs
        end

        def fallback_transactions
          event.canonical_transactions.order("date desc")
        end

        def no_filters_applied?
          tag_id.blank? && user_id.blank? && transaction_type.blank? &&
            direction.blank? && minimum_amount.blank? && maximum_amount.blank? &&
            missing_receipts.blank? && category_slug.blank? && merchant_id.blank? &&
            search.blank? && start_date.blank? && end_date.blank?
        end

        def filter_by_type(transactions)
          case transaction_type
          when "card_charge" then transactions.card_charge
          when "ach" then transactions.ach
          when "check" then transactions.check
          when "other" then transactions.other
          when "paypal" then transactions.paypal
          when "wire" then transactions.wire
          when "transfer" then transactions.transfer
          when "hcb_transfer" then transactions.hcb_transfer
          else transactions
          end
        end
      end
    end
  end
end
