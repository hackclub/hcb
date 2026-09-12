# frozen_string_literal: true

module Api
  module V5
    class ReceiptsController < ApplicationController
      # Two distinct lists behind one route, as in v4: the receipts on a given
      # transaction, or the caller's own Receipt Bin. The bin is a policy scope;
      # the transaction's receipts are reached through an authorized transaction.
      # v4 reached the bin via `skip_authorization`, which this replaces.
      after_action :verify_authorized, only: :index

      def index
        @receipts =
          if params[:transaction_id].present?
            # `skip_policy_scope` rather than dropping the after_action: the bin
            # branch below still has to prove it scoped, and skipping the
            # callback outright would excuse both.
            skip_policy_scope
            item = authorize Ledger::Item.find_by_public_id!(params[:transaction_id]), :show_any_attribute?
            item.receipts.includes(:user)
          else
            skip_authorization
            policy_scope(Receipt).in_receipt_bin.includes(:user)
          end

        @receipts = paginate_cursor(@receipts.to_a, &:public_id)
      end

      require_oauth2_scope "receipts:read", :index
    end
  end
end
