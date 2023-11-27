# frozen_string_literal: true

class DonationPolicy < ApplicationPolicy
  def show?
    record.event.users.include?(user) || user&.admin?
  end

  def start_donation?
    record.event.donation_page_enabled
  end

  def make_donation?
    record.event.donation_page_enabled && !record.event.demo_mode?
  end
  
  def make_donation_from_product?
    record.event.donation_page_enabled && !record.event.demo_mode?
  end

  def index?
    user&.admin?
  end

  def export?
    record.event.users.include?(user) || user&.admin?
  end

  def refund?
    user&.admin?
  end

end
