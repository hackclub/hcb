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
      # A transaction can touch more than one org (e.g. a transfer between
      # orgs), so check every event it's mapped to — not just the primary
      # ledger's — to match the legacy `hcb_code.events` behavior.
      return false unless member_of_any_event?

      # A tag can only be applied to a transaction in an event it belongs to, so
      # a member of two organizations can't attach one org's tag to the other's.
      tag.nil? || events.include?(tag.event)
    end

    private

    def events
      @events ||= record.all_ledgers.filter_map { |ledger| ledger.event || ledger.card_grant&.event }.uniq
    end

    def member_of_any_event?
      return false if user.nil?
      return true if user.admin?

      events.any? { |event| OrganizerPosition.role_at_least?(user, event, :member) }
    end

    def admin_or_member?
      user&.admin? || OrganizerPosition.role_at_least?(user, record.primary_ledger&.event, :member)
    end

  end

end
