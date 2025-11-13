# frozen_string_literal: true

class Invoice
  class MarkDepositedsJob < ApplicationJob
    queue_as :default
    def perform
      Invoice.where(aasm_state: :paid_v2).find_each do |invoice|
        if invoice.canonical_transactions.count >= 2 || invoice.manually_marked_as_paid? || invoice.completed_deprecated?
          invoice.mark_deposited!
        end
      end
    end

  end

end
