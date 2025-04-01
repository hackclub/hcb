# frozen_string_literal: true

class HcbCodePolicy < ApplicationPolicy
  def show?
    user&.auditor? || present_in_events?
  end

  def memo_frame?
    user&.admin?
  end

  def edit?
    member_role_present?
  end

  def update?
    member_role_present?
  end

  def comment?
    member_role_present?
  end

  def attach_receipt?
    user&.admin? || member_role_present? || user_made_purchase?
  end

  def send_receipt_sms?
    user&.admin?
  end

  def dispute?
    member_role_present?
  end

  def pin?
    member_role_present?
  end

  def toggle_tag?
    member_role_present?
  end

  def invoice_as_personal_transaction?
    member_role_present?
  end

  def link_receipt_modal?
    member_role_present?
  end

  def user_made_purchase?
    record.stripe_card? && record.stripe_cardholder&.user == user
  end

  alias receiptable_upload? user_made_purchase?

  private

  def present_in_events?
    record.events.select { |e| e.try(:users).try(:include?, user) }.present?
  end

  def member_role_present?
    record.events.any? do |e|
      e.try(:users).try(:include?, user) && OrganizerPosition.role_at_least?(user, e, :member)
    end
  end

end
