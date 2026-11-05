# frozen_string_literal: true

module RepaymentService
  # Undoes RepaymentService::Mark, putting both transactions back to the
  # categories they had. Repayment transfers are undone by rejecting the
  # transfer instead, since money actually moved.
  class Unmark
    def initialize(repayment:)
      @repayment = repayment
    end

    def run
      raise ArgumentError, "only repayments by a ledger item can be unmarked" if @repayment.repaying_ledger_item.nil?

      ActiveRecord::Base.transaction do
        @repayment.revert_categories!
        @repayment.destroy!
      end
    end

  end
end
