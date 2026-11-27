# frozen_string_literal: true

class Ledger
  class ItemPolicy < ApplicationPolicy
    def show?
      if record.primary_ledger
        LedgerPolicy.new(user, record.primary_ledger).show? || cardholder?
      else
        # Item is unampped, only admins can see it
        user&.admin?
      end
    end

    alias_method :hcb?, :show?

    def pin?
      admin_or_member?
    end

    def unpin?
      admin_or_member?
    end

    def rename?
      admin_or_member?
    end

    def invoice_as_personal_transaction?
      admin_or_member?
    end

    def dispute?
      admin_or_member?
    end

    # Members link money in on their own ledger. A manager of another
    # organization can link a transfer it sent, from here or from their own
    # side. Repayment.match_candidates decides which transactions each sees.
    def mark_repayment?
      admin_or_member? || (user.present? && user.manageable_events.exists? && DisbursementPolicy.new(user, Disbursement.new(destination_event: record.primary_ledger&.event)).repay?)
    end

    def toggle_tag?(tag = nil)
      # A ledger item belongs to a single primary ledger (owned by an event or a
      # card grant), so a tag can only be applied within that one event.
      return false if event.nil?
      return false unless user&.admin? || OrganizerPosition.role_at_least?(user, event, :member)

      tag.nil? || event == tag.event
    end

    private

    # A cardholder needn't hold a position in the card's event (a grantee, or
    # someone whose card outlived their membership), but the charges on their
    # own card are theirs to see, as HcbCodePolicy#show? already lets the
    # cardholder in: they're the one who has to upload the receipt. The rest of
    # the ledger (a grant's topups and withdrawals, say) stays the event's.
    #
    # `user` is nil for signed out requests, and a charge whose cardholder
    # can't be resolved has a nil owner, so without the first clause the two
    # compare equal and an anonymous request is treated as the cardholder.
    def cardholder?
      user.present? && record.linked_object_type == "CardCharge" && record.linked_object&.stripe_cardholder&.user == user
    end

    def event
      @event ||= record.primary_ledger&.event || record.primary_ledger&.card_grant&.event
    end

    def admin_or_member?
      user&.admin? || OrganizerPosition.role_at_least?(user, record.primary_ledger&.event, :member)
    end

  end

end
