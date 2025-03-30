# frozen_string_literal: true

class HcbCodePolicy < ApplicationPolicy
  def show?
    user&.auditor? || present_in_events?
  end

  def memo_frame?
    user&.admin?
  end

  def edit?
    OrganizerPosition.role_at_least?(user, event, :member) || present_in_events?
  end

  def update?
    OrganizerPosition.role_at_least?(user, event, :member) || present_in_events?
  end

  def comment?
    OrganizerPosition.role_at_least?(user, event, :member) || present_in_events?
  end

  def attach_receipt?
    OrganizerPosition.role_at_least?(user, event, :member) && (present_in_events? || user_made_purchase?)
  end

  def send_receipt_sms?
    user&.admin?
  end

  def dispute?
    OrganizerPosition.role_at_least?(user, event, :member) || present_in_events?
  end

  def pin?
    OrganizerPosition.role_at_least?(user, event, :member) || present_in_events?
  end

  def toggle_tag?
    OrganizerPosition.role_at_least?(user, event, :member) || present_in_events?
  end

  def invoice_as_personal_transaction?
    OrganizerPosition.role_at_least?(user, event, :member) || present_in_events?
  end

  def link_receipt_modal?
    OrganizerPosition.role_at_least?(user, event, :member) || present_in_events?
  end

  def user_made_purchase?
    record.stripe_card? && record.stripe_cardholder&.user == user
  end

  alias receiptable_upload? user_made_purchase?

  private

  def present_in_events?
    record.events.select { |e| e.try(:users).try(:include?, user) }.present?
  end

  def event?(role)
    if record.respond_to?(:events)
      return record.events.any? do |event|
        OrganizerPosition.role_at_least?(user, event, role)
      end
    end

    event = if record.is_a?(Reimbursement::Report)
              record.event
            elsif record.is_a?(Event)
              record
            else
              record.event
            end

    OrganizerPosition.role_at_least?(user, event, role)
  end

end
