# frozen_string_literal: true

class CardGrant
  # One-time-use grant cards are frozen by the system after their first
  # authorization. When that charge is fully refunded or released, the grant's
  # balance is restored, so we defrost the card while keeping it one-time-use.
  class DefrostOneTimeUseJob < ApplicationJob
    queue_as :default

    DEFROSTABLE_STATUSES = %w[reversed released].freeze

    def perform(ledger_item_id:)
      item = Ledger::Item.find_by(id: ledger_item_id)
      return unless item&.linked_object_type == "CardCharge"
      return unless item.status.in?(DEFROSTABLE_STATUSES)

      card = item.linked_object&.stripe_card
      grant = card&.card_grant
      return unless grant&.one_time_use? && grant.active?
      return unless card.frozen? && card.last_frozen_by == User.system_user
      return if other_live_charges?(card, item)

      PaperTrail.request(whodunnit: User.system_user.id) do
        card.defrost!(keep_one_time_use: true)
      end
    end

    private

    def other_live_charges?(card, item)
      Ledger::Item
        .where(linked_object_type: "CardCharge", linked_object_id: card.card_charges.select(:id))
        .where.not(id: item.id)
        .where(status: %w[pending settled])
        .exists?
    end

  end

end
