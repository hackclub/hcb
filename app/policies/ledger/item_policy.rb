# frozen_string_literal: true

class Ledger
  class ItemPolicy < ApplicationPolicy
    def show?
      if record.primary_ledger
        LedgerPolicy.new(user, record.primary_ledger).show?
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

    def toggle_tag?(tag = nil)
      # A ledger item belongs to a single primary ledger (owned by an event or a
      # card grant), so a tag can only be applied within that one event.
      return false if event.nil?
      return false unless user&.admin? || OrganizerPosition.role_at_least?(user, event, :member)

      tag.nil? || event == tag.event
    end

    private

    def event
      @event ||= record.primary_ledger&.event || record.primary_ledger&.card_grant&.event
    end

    def admin_or_member?
      user&.admin? || OrganizerPosition.role_at_least?(user, record.primary_ledger&.event, :member)
    end

  end

end
