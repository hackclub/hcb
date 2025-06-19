# frozen_string_literal: true

class ReceiptablePolicy < ApplicationPolicy
  def link?
    user&.admin? || present_in_events? || Pundit.policy(user, record).try(:receiptable_upload?)
  end

  def link_modal?
    user&.admin? || present_in_events? || Pundit.policy(user, record).try(:receiptable_upload?)
  end

  def upload?
    user&.admin? || present_in_events? || Pundit.policy(user, record).try(:receiptable_upload?)
  end

  private

  def present_in_events?
    # Assumption: Receiptable has an association to Event
    events = (record.try(:events) || [record.event]).compact
    events.any? { |event| OrganizerPosition.role_at_least?(user, event, :member) }
  end

end
