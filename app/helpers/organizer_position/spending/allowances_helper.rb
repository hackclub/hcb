# frozen_string_literal: true

class OrganizerPosition
  module Spending
    module AllowancesHelper
      def spending_item_created_date(item)
        item.is_a?(Ledger::Item) ? (item.pending_at || item.datetime) : item.created_at
      end

      def sorted_spending_items(control)
        spending_items = []
        spending_items.concat(control.transactions.includes(:author, :hcb_code)) unless params[:filter] == "allowances"
        spending_items.concat(control.allowances.includes(:authorized_by)) unless params[:filter] == "transactions"
        spending_items.sort_by { |item| spending_item_created_date(item) }.reverse!
      end

    end

  end

end
