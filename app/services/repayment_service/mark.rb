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

        repayment = Repayment.new(repaying_ledger_item: repaying, created_by: @created_by)
        repayment.allocations.build(repaid_ledger_item: repaid, amount_cents: repaying.amount_cents)
        repayment.save!
        # Changing the sender's books takes the same access as sending from them.
        sender = repayment.repaying_transfer&.source_event
        recategorize_sender = sender.present? && EventPolicy.new(@created_by, sender).update?
        repayment.allocations.each { |allocation| allocation.apply_categories!(recategorize_sender:) }
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

    # Looked up among what the picker offers, so an id from another ledger or
    # of a different amount is treated as not found rather than revealed.
    def other_ledger_item
      @other_ledger_item ||= Repayment.match_candidates(@ledger_item).find_by_hashid(@other_ledger_item_hashid)
    end

  end
end
