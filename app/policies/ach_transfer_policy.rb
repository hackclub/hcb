# frozen_string_literal: true

class AchTransferPolicy < ApplicationPolicy
  # Index-route authorization. Today the v4 API does this three different ways
  # — authorize the parent event, `skip_authorization` plus a hand-written
  # scope, or authorize an unrelated record and read through its association —
  # and only comments use Pundit's actual answer. This is that answer: the same
  # rule as #visible_attributes' base tier, in SQL.
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user&.auditor?

      scope.where(event: Event.visible_to(user))
    end

  end

  def index?
    user&.auditor?
  end

  def new?
    auditor_or_user?
  end

  def create?
    user_who_can_transfer? && !record.event.demo_mode
  end

  def show?
    user&.auditor?
  end

  def view_account_routing_numbers?
    admin_or_manager?
  end

  # See ApplicationPolicy#visible_attributes.
  #
  # The base tier is what a transparent organization shows to anyone, signed in
  # or not. It matches what `Api::Entities::AchTransfer` exposes in v3, so v5
  # can serve transparency traffic without a second serializer.
  def visible_attributes
    @visible_attributes ||= begin
      attrs = []

      if transparent_or_reader?
        attrs += %i[amount_cents date status recipient_name payment_for sender]
        attrs += %i[recipient_email bank_name] if auditor_or_user?

        # `:account_number` (full) and `:account_number_last4` are one
        # permission but two fields: the web UI reveals the whole number to a
        # manager while the API ships four digits. That split predates this
        # list and nobody recorded whether it was deliberate — listing both
        # keeps today's behavior while making the difference visible in one
        # place.
        attrs += %i[account_number account_number_last4 routing_number] if view_account_routing_numbers?
      end

      attrs
    end
  end

  def cancel?
    user_who_can_transfer?
  end

  def transfer_confirmation_letter?
    user_who_can_transfer?
  end

  def start_approval?
    user&.admin?
  end

  def approve?
    user&.admin?
  end

  def reject?
    user&.admin?
  end

  def toggle_speed?
    user&.admin?
  end


  # Strong parameters for writes — the input counterpart to
  # #visible_attributes. `scheduled_on` is admin-only: scheduling a transfer
  # for a future date is an operations action, not a member one.
  def permitted_attributes
    attrs = %i[routing_number account_number recipient_email bank_name recipient_name
               amount_money payment_for send_email_notification invoiced_at file]
    attrs << :scheduled_on if !!user&.admin?
    attrs
  end

  private

  def user_who_can_transfer?
    EventPolicy.new(user, record.event).create_transfer?
  end

  # See ApplicationPolicy#event_reader? for why these resolve from memoized id
  # sets rather than OrganizerPosition.role_at_least?.
  def auditor_or_user?
    !!user&.auditor? || event_reader?
  end

  def admin_or_user?
    user&.admin? || OrganizerPosition.role_at_least?(user, record.event, :reader)
  end

  def admin_or_manager?
    !!user&.admin? || event_manager?
  end

end
