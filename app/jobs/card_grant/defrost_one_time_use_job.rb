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

    # Only approved authorizations freeze one-time-use cards; force captures and
    # declined authorizations cannot.
    # Compare authorization times, since late imports and backfills make charge
    # insertion order unreliable, and settlement can change an item's datetime.
    def froze_the_card?(card, item)
      authorized_charges = card.card_charges
                               .joins(:raw_pending_stripe_transaction)
                               .where("raw_pending_stripe_transactions.stripe_transaction ->> 'approved' = 'true'")
      Ledger::Item
        .where(linked_object_type: "CardCharge", linked_object_id: authorized_charges.select(:id))
        .order(Arel.sql("COALESCE(pending_at, datetime) DESC"), id: :desc)
        .pick(:id) == item.id
    end

  end

end
