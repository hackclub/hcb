# frozen_string_literal: true

class HcbCodePolicy < ApplicationPolicy
  def show?
    user&.admin? || present_in_events?
  end

  def memo_frame?
    user&.admin?
  end

  def edit?
    !reader? && (user&.admin? || present_in_events?)
  end

  def update?
    !reader? && (user&.admin? || present_in_events?)
  end

  def comment?
    !reader? && (user&.admin? || present_in_events?)
  end

  def attach_receipt?
    !reader? && (user&.admin? || present_in_events? || user_made_purchase?)
  end

  def send_receipt_sms?
    user&.admin?
  end

  def dispute?
    !reader? && (user&.admin? || present_in_events?)
  end

  def pin?
    !reader? && (user&.admin? || present_in_events?)
  end

  def toggle_tag?
    !reader? && (user&.admin? || present_in_events?)
  end

  def invoice_as_personal_transaction?
    !reader? && (user&.admin? || present_in_events?)
  end

  def link_receipt_modal?
    !reader? && (user&.admin? || present_in_events?)
  end

  def user_made_purchase?
    record.stripe_card? && record.stripe_cardholder&.user == user
  end

  alias receiptable_upload? user_made_purchase?

  private

  def present_in_events?
    record.events.select { |e| e.try(:users).try(:include?, user) }.present?
  end

  def reader?
    OrganizerPosition.find_by(user: user, event: record.events)&.reader?
  end

end
