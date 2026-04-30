# frozen_string_literal: true

class DonationPolicy < ApplicationPolicy
  def show?
    OrganizerPosition.role_at_least?(user, record.event, :reader) || auditor?
  end

  def create?
    OrganizerPosition.role_at_least?(user, record.event, :reader) || admin?
  end

  def start_donation?
    record.event.donation_page_available?
  end

  def make_donation?
    record.event.donation_page_available? && !record.event.demo_mode?
  end

  def index?
    auditor?
  end

  def export?
    OrganizerPosition.role_at_least?(user, record.event, :reader) || auditor?
  end

  def export_donors?
    OrganizerPosition.role_at_least?(user, record.event, :reader) || auditor?
  end

  def update?
    OrganizerPosition.role_at_least?(user, record.event, :manager) || admin?
  end

  def refund?
    admin?
  end

end
