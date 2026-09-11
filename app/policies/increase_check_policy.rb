# frozen_string_literal: true

class IncreaseCheckPolicy < ApplicationPolicy
  def new?
    auditor_or_user?
  end

  def create?
    user_who_can_transfer?
  end

  def approve?
    user&.admin?
  end

  def stop?
    user_who_can_transfer? && record.can_stop?
  end

  def reject?
    user_who_can_transfer?
  end

  # See ApplicationPolicy#visible_attributes. v3's `check` entity publishes
  # only amount, date and status — the recipient and their address are not
  # public.
  def visible_attributes
    @visible_attributes ||= begin
      attrs = []
      attrs += %i[amount_cents status memo] if transparent_or_reader?
      attrs += %i[recipient_name recipient_email payment_for check_number
                  address_line1 address_line2 address_city address_state address_zip] if auditor_or_user?
      attrs
    end
  end

  private

  def auditor_or_user?
    user&.auditor? || OrganizerPosition.role_at_least?(user, record.event, :reader)
  end

  def admin_or_user?
    user&.admin? || OrganizerPosition.role_at_least?(user, record.event, :reader)
  end

  def user_who_can_transfer?
    EventPolicy.new(user, record.event).create_transfer?
  end

end
