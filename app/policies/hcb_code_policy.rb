# frozen_string_literal: true

class HcbCodePolicy < ApplicationPolicy
  def show?
    user&.auditor? || present_in_events?
  end

  def memo_frame?
    user&.admin?
  end

  def edit?
    gte_member_in_events?
  end

  def update?
    gte_member_in_events?
  end

  def comment?
    gte_member_in_events?
  end

  def attach_receipt?
    user&.admin? || gte_member_in_events? || user_made_purchase?
  end

  def send_receipt_sms?
    user&.admin?
  end

  def dispute?
    gte_member_in_events?
  end

  def pin?
    gte_member_in_events?
  end

  def toggle_tag?
    gte_member_in_events?
  end

  def invoice_as_personal_transaction?
    gte_member_in_events?
  end

  def link_receipt_modal?
    gte_member_in_events?
  end

  def user_made_purchase?
    record.stripe_card? && record.stripe_cardholder&.user == user
  end

  alias receiptable_upload? user_made_purchase?

  private

  def present_in_events?
    record.events.select { |e| e.try(:users).try(:include?, user) }.present?
  end

  # if users have permissions greater than or equal to member in events
  def gte_member_in_events?
    user&.admin? || record.events.any? do |e|
      e.try(:users).try(:include?, user) && OrganizerPosition.role_at_least?(user, e, :member)
    end
  end

end
