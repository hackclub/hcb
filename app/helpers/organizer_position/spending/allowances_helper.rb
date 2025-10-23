# frozen_string_literal: true

class OrganizerPosition
  module Spending
    module AllowancesHelper
      def spending_item_created_date(item)
        if item.is_a?(CanonicalPendingTransaction) && item.raw_pending_stripe_transaction.present?
          return Time.at(item.raw_pending_stripe_transaction.stripe_transaction["created"])
        end

        return item.created_at
      end

      def sorted_spending_items(control)
        spending_items = []
        spending_items << control.transactions.sort_by(&:created_at).reverse! unless params[:filter] == "allowances"
        spending_items << control.allowances.order(created_at: :desc) unless params[:filter] == "transactions"
        spending_items.flatten!.sort_by(&:created_at).reverse!
      end

    end

  end

end
