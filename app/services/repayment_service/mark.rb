# frozen_string_literal: true

module RepaymentService
  # Marks money that came in on an organization's ledger as paying its
  # expenses back. Either side can start it: from the income ("Mark as a
  # repayment"), choosing one or more expenses that add up to it, or from an
  # expense ("Mark as repaid"), choosing income of the same amount.
  class Mark
    # Raised with a message meant for whoever is marking the repayment.
    class UserError < ArgumentError; end

    def initialize(ledger_item:, other_ledger_item_hashids:, created_by:)
      @ledger_item = ledger_item
      @other_ledger_item_hashids = Array(other_ledger_item_hashids).reject(&:blank?).uniq
      @created_by = created_by
    end

    def run
      raise UserError, "This transaction isn't on an organization's ledger." if event.nil?
      raise UserError, "Choose a transaction to match this one with." if @other_ledger_item_hashids.empty?
      raise UserError, "That transaction can't be matched with this one." if other_ledger_items.size != @other_ledger_item_hashids.size

      # Only money in can be matched with several transactions: an expense is repaid by one payment.
      raise UserError, "An expense can only be repaid by one transaction." if @ledger_item.amount_cents.negative? && other_ledger_items.size > 1

      repaid, repaying = @ledger_item.amount_cents.negative? ? [[@ledger_item], other_ledger_items.first] : [other_ledger_items, @ledger_item]
      unless -repaid.sum(&:amount_cents) == repaying.amount_cents
        raise UserError, "The expenses you choose must add up to #{repaying.amount.format}."
      end

      ActiveRecord::Base.transaction do
        # Two people marking at once would both pass the "already repaid"
        # checks without this. Locking in id order keeps them from deadlocking.
        Ledger::Item.where(id: [*repaid.map(&:id), repaying.id]).order(:id).lock.load

        repayment = Repayment.new(repaying_ledger_item: repaying, created_by: @created_by)
        repaid.each { |item| repayment.allocations.build(repaid_ledger_item: item, amount_cents: -item.amount_cents) }
        repayment.save!
        repayment.allocations.each(&:apply_categories!)
        repayment
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      # All were offered by the picker, so one changed since: someone else linked it first.
      raise UserError, "One of these transactions was just linked to something else. Refresh and try again."
    end

    private

    def event
      @event ||= @ledger_item.primary_ledger&.event
    end

    # Looked up among what the picker offers, so an id from another ledger or
    # of an amount that can't match is treated as not found rather than revealed.
    def other_ledger_items
      @other_ledger_items ||= Repayment.match_candidates(@ledger_item, @created_by).where_hashid(@other_ledger_item_hashids).to_a
    end

  end
end
