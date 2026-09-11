# frozen_string_literal: true

class HcbCodePolicy < ApplicationPolicy
  def show?
    user&.auditor? || present_in_events? || (record.stripe_cardholder.present? && record.stripe_cardholder.user == user)
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

  def toggle_tag?
    gte_member_in_events?
  end

  def link_receipt_modal?
    gte_member_in_events?
  end

  # `user` is nil for signed out requests, and a charge whose cardholder can't
  # be resolved has a nil owner, so without the first clause the two compare
  # equal and an anonymous request is treated as the purchaser.
  def user_made_purchase?
    user.present? && record.stripe_card? && record.stripe_cardholder&.user == user
  end

  alias receiptable_upload? user_made_purchase?

  # See ApplicationPolicy#visible_attributes. Public tier = v3's `transaction`
  # entity: amount, memo, date, type, pending, receipt/comment counts, and the
  # organization/user/tag associations.
  def visible_attributes
    @visible_attributes ||= begin
      attrs = []

      if transparent_or_reader?
        attrs += %i[date amount_cents memo pending declined reversed code tags
                    missing_receipt organization organization_id]
        # The polymorphic subtree. Each is gated again by its own policy, so
        # listing it here only says the relationship may be disclosed.
        attrs += %i[card_charge donation expense_payout invoice check transfer
                    ach_transfer check_deposit wise_transfer wire_transfer]
      end

      # Internal bookkeeping, not part of what v3 publishes.
      attrs += %i[has_custom_memo lost_receipt appearance] if event_reader? || !!user&.auditor?

      attrs
    end
  end

  # An HcbCode can span several organizations; it is visible if any of them
  # is transparent or readable.
  def transparent_or_reader?
    return true if user&.auditor?

    record.events.any? { |event| event.is_public? || (user.present? && user.readable_event_ids.include?(event.id)) }
  end

  private

  def present_in_events?
    record.events.any? { |event| OrganizerPosition.role_at_least?(user, event, :reader) }
  end

  # if users have permissions greater than or equal to member in events
  def gte_member_in_events?
    return false if user.nil? # dont run checks if the user isnt signed in
    return true if user&.admin?

    record.events.any? do |e|
      OrganizerPosition.role_at_least?(user, e, :member)
    end
  end

end
