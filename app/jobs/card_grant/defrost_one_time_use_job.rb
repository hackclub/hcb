# frozen_string_literal: true

class CardGrant
  # One-time-use grant cards are frozen by the system after each purchase. When
  # the purchase that froze the card is refunded or released, the freeze has no
  # reason to stand, so we defrost while keeping the grant one-time-use.
  class DefrostOneTimeUseJob < ApplicationJob
    queue_as :default

    DEFROSTABLE_STATUSES = %w[reversed released].freeze

    # Stripe rejects activating a card that it considers permanently unusable
    # (a canceled card, most often). Retrying can't fix that.
    discard_on(Stripe::InvalidRequestError) { |_job, error| Rails.error.report(error) }

    def perform(ledger_item_id:)
      item = Ledger::Item.find_by(id: ledger_item_id)
      return unless item&.linked_object_type == "CardCharge"
      return unless item.status.in?(DEFROSTABLE_STATUSES)

      card = item.linked_object&.stripe_card
      grant = card&.card_grant
      return unless grant&.one_time_use? && grant.active?
      # Organizers can't defrost a card while the org is frozen, so neither should we.
      return if card.event.financially_frozen?
      # Only undo a freeze HCB applied, never an organizer's.
      return unless card.frozen? && card.last_frozen_by == User.system_user
      return unless froze_the_card?(card, item)

      PaperTrail.request(whodunnit: User.system_user.id) do
        card.defrost!(keep_one_time_use: true)
      end
    end

    private

    # The card is frozen because of its latest charge, so only that charge
    # reversing lifts the freeze. Earlier charges were spent under freezes an
    # organizer has since lifted.
    def froze_the_card?(card, item)
      card.card_charges.order(created_at: :desc, id: :desc).first&.id == item.linked_object_id
    end

  end

end
