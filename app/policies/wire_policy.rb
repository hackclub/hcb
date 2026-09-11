# frozen_string_literal: true

class WirePolicy < ApplicationPolicy
  def new?
    auditor_or_user?
  end

  def show?
    user&.auditor?
  end

  def create?
    user_who_can_transfer?
  end

  def send_wire?
    user&.admin?
  end

  def reject?
    user_who_can_transfer?
  end

  def edit?
    user&.admin?
  end

  def update?
    user&.admin?
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


  # See ApplicationPolicy#visible_attributes. v3's `wire_transfer` entity publishes
  # the amounts, currency, date, status, the beneficiary's name and the sender.
  # The beneficiary's email, country and address are not public.
  def visible_attributes
    @visible_attributes ||= begin
      attrs = []
      attrs += %i[amount_cents usd_amount_cents currency state recipient_name sender organization_id] if transparent_or_reader?
      attrs += %i[recipient_email recipient_country payment_for memo return_reason sent_at
                  address_line1 address_line2 address_city address_state address_postal_code] if event_reader? || !!user&.auditor?
      attrs
    end
  end

end
