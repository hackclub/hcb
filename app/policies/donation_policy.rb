# frozen_string_literal: true

class DonationPolicy < ApplicationPolicy
  def show?
    OrganizerPosition.role_at_least?(user, record.event, :reader) || user&.auditor?
  end

  def create?
    OrganizerPosition.role_at_least?(user, record.event, :reader) || user&.admin?
  end

  def payment_intent?
    create?
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
    OrganizerPosition.role_at_least?(user, record.event, :reader) || user&.auditor?
  end

  def export_donors?
    OrganizerPosition.role_at_least?(user, record.event, :reader) || user&.auditor?
  end

  def update?
    OrganizerPosition.role_at_least?(user, record.event, :manager) || user&.admin?
  end

  def refund?
    user&.admin?
  end


  # See ApplicationPolicy#visible_attributes.
  #
  # v3 publishes the donor's name (masked to "Anonymous" by Donation#name),
  # the anonymous flag and the avatar. It does NOT publish the email, and the
  # email is *not* masked for anonymous donations — so it must never reach the
  # transparency tier.
  def visible_attributes
    @visible_attributes ||= begin
      attrs = []
      attrs += %i[amount_cents recurring donor status date refunded deposited in_transit] if transparent_or_reader?
      attrs += %i[donor_email attribution payment_method message donated_at recurring_donor_id] if event_reader? || !!user&.auditor?
      attrs
    end
  end

end
