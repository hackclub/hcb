# frozen_string_literal: true

module RepaymentService
  # Marks money that came in on an organization's ledger as paying one of its
  # expenses back. Either side can start it: from the income ("This was a
  # repayment") or from the expense ("This was repaid").
  class Mark
    # Raised with a message meant for whoever is marking the repayment.
    class UserError < ArgumentError; end

    def initialize(ledger_item:, other_ledger_item_hashid:, created_by:)
      @ledger_item = ledger_item
      @other_ledger_item_hashid = other_ledger_item_hashid
      @created_by = created_by
    end

    def run
      raise UserError, "This transaction isn't on an organization's ledger." if event.nil?

      repaid, repaying = @ledger_item.amount_cents.negative? ? [@ledger_item, other_ledger_item] : [other_ledger_item, @ledger_item]
      raise UserError, "That transaction can't be matched with this one." if repaid.nil? || repaying.nil?

      ActiveRecord::Base.transaction do
        # Two people marking at once would both pass the "already repaid"
        # checks without this. Locking in id order keeps them from deadlocking.
        Ledger::Item.where(id: [repaid.id, repaying.id]).order(:id).lock.load

        repayment = Repayment.create!(repaid_ledger_item: repaid, repaying_ledger_item: repaying, amount_cents: repaying.amount_cents, created_by: @created_by)
        repayment.apply_categories!
        repayment
      end
    rescue ActiveRecord::RecordInvalid => e
      raise UserError, e.record.errors.full_messages.to_sentence
    rescue ActiveRecord::RecordNotUnique
      raise UserError, "That transaction has already been marked as a repayment."
    end

    private

    def event
      @event ||= @ledger_item.primary_ledger&.event
    end

    # Looked up among the organization's own transactions, so an id from
    # another ledger is treated as not found rather than revealed.
    def other_ledger_item
      @other_ledger_item ||= begin
        candidates = @ledger_item.amount_cents.negative? ? Repayment.unused_repaying_ledger_items(event) : Repayment.unrepaid_ledger_items(event)
        candidates.find_by_hashid(@other_ledger_item_hashid)
      end
    end

  end
end
