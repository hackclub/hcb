# frozen_string_literal: true

class CardGrant
  # Force captures skip authorization, so the authorization webhook never sees
  # them and never freezes the card. Freeze one-time-use grant cards when a
  # force capture is imported instead.
  class FreezeOneTimeUseJob < ApplicationJob
    queue_as :default

    def perform(raw_stripe_transaction_id:)
      raw_stripe_transaction = RawStripeTransaction.find_by(id: raw_stripe_transaction_id)
      return unless raw_stripe_transaction&.force_capture?

      card = raw_stripe_transaction.card_charge&.stripe_card
      grant = card&.card_grant
      return unless grant&.one_time_use? && grant.active?
      # Leave frozen, canceled, and never-activated cards alone, so an
      # organizer's freeze keeps its author.
      return unless card.active?

      PaperTrail.request(whodunnit: User.system_user.id) do
        card.freeze!(frozen_by: User.system_user)
      end
    end

  end

end
