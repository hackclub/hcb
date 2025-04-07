# frozen_string_literal: true

class DonationPolicy < ApplicationPolicy
  def show?
    record.event.users.include?(user) || user&.auditor?
  end

  def create?
    record.event.users.include?(user) || user&.admin?
  end

  def start_donation?
    record.event.donation_page_available?
  end

  def make_donation?
    record.event.donation_page_available? && !record.event.demo_mode?
  end

  def index?
    user&.auditor?
  end

  def export?
    record.event.users.include?(user) || user&.auditor?
  end

  def export_donors?
    record.event.users.include?(user) || user&.auditor?
  end

  def refund?
    user&.admin?
  end

end
