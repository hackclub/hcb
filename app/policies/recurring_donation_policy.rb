# frozen_string_literal: true

class RecurringDonationPolicy < ApplicationPolicy
  def create?
    record.event.donation_page_available? && !record.event.demo_mode?
  end

  def pay?
    true
  end

  def finished?
    true
  end

  def show?
    true
  end

  def edit?
    !record.canceled?
  end

  def update?
    !record.canceled?
  end

  def cancel?
    !record.canceled?
  end

end
