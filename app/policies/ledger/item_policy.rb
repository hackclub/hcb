# frozen_string_literal: true

class Ledger
  class ItemPolicy < ApplicationPolicy
    # Index-route authorization for the v5 transactions resource. A ledger item
    # is visible when any ledger it is mapped to belongs to an organization the
    # viewer may read — including card-grant ledgers, which reach their
    # organization through the grant.
    #
    # This is what lets v5 transactions use `policy_scope` at all: unlike the
    # HcbCode-era index, which was a projection of two engines with no relation
    # to filter, `Ledger::Item` is an ordinary relation.
    class Scope < ApplicationPolicy::Scope
      def resolve
        return scope.all if user&.auditor?

        visible_events = Event.visible_to(user)
        visible_ledgers = ::Ledger.where(event: visible_events)
                                  .or(::Ledger.where(card_grant: CardGrant.where(event: visible_events)))

        scope.where(id: ::Ledger::Mapping.where(ledger: visible_ledgers).select(:ledger_item_id))
      end

    end

    def show?
      if record.primary_ledger
        LedgerPolicy.new(user, record.primary_ledger).show?
      else
        # Item is unampped, only admins can see it
        user&.admin?
      end
    end

    alias_method :hcb?, :show?

    # See ApplicationPolicy#visible_attributes. Public tier = v3's
    # `transaction` entity: amount, memo, date, type, pending, receipt and
    # comment counts, and the organization and tag associations.
    def visible_attributes
      @visible_attributes ||= begin
        attrs = []

        if transparent_or_reader?
          attrs += %i[date amount_cents memo type status pending tags
                      receipts comments organization organization_id linked_object]
        end

        attrs += %i[has_custom_memo system_memo missing_receipt lost_receipt appearance code] if event_reader? || !!user&.auditor?

        attrs
      end
    end

    # A ledger item reaches its organization through its primary ledger, which
    # may be owned by an event or by a card grant.
    def policy_event
      ledger = record.primary_ledger
      return nil if ledger.nil?

      ledger.event || ledger.card_grant&.event
    end

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

    private

    def admin_or_member?
      user&.admin? || OrganizerPosition.role_at_least?(user, record.primary_ledger&.event, :member)
    end

  end

end
