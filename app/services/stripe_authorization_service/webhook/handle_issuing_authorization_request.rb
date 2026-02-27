# frozen_string_literal: true

module StripeAuthorizationService
  module Webhook
    class HandleIssuingAuthorizationRequest
      attr_reader :declined_reason

      def initialize(stripe_event:)
        @stripe_event = stripe_event
      end

      def run
        approve?
      end

      def card
        @card ||= StripeCard.includes(:card_grant).find_by(stripe_id: stripe_card_id)
      end

      private

      def auth
        @stripe_event[:data][:object]
      end

      def auth_id
        auth[:id]
      end

      def amount_cents
        auth[:pending_request][:amount]
      end

      def stripe_card_id
        auth[:card][:id]
      end

      def card_balance_available
        @card_balance_available ||= card.balance_available
      end

      def event
        card.event
      end

      def decline_with_reason!(reason)
        @declined_reason = reason
        set_metadata!(declined_reason: reason)

        false
      end

      def cash_withdrawal?
        auth[:merchant_data][:category_code] == "6011"
      end

      def approve?
        return decline_with_reason!("event_frozen") if event.financially_frozen?
        return decline_with_reason!("user_locked") if card.user&.locked?

        if forbidden_merchant_category? && !card.user&.admin?
          AdminMailer
            .with(stripe_card: card, merchant_category:)
            .blocked_authorization
            .deliver_later

          return decline_with_reason!("merchant_not_allowed")
        end

        return decline_with_reason!("merchant_not_allowed") unless merchant_allowed?

        return decline_with_reason!("inadequate_balance") if card_balance_available < amount_cents

        if cash_withdrawal?
          unless card.cash_withdrawal_enabled?
            return decline_with_reason!("cash_withdrawals_not_allowed")
          end

          if amount_cents > 500_00
            return decline_with_reason!("exceeds_approval_amount_limit")
          end
        end

        return decline_with_reason!("user_cards_locked") if card.user.cards_locked? && event.plan.card_lockable?

        set_metadata!

        true
      end

      def set_metadata!(additional = {})
        return if Rails.env.test?

        default_metadata = {
          current_balance_available: card_balance_available,
        }

        StripeService::Issuing::Authorization.update(
          auth_id,
          { metadata: default_metadata.deep_merge(additional) }
        )
      end

      def merchant_category
        auth[:merchant_data][:category]
      end

      def forbidden_merchant_category?
        StripeAuthorizationService::FORBIDDEN_MERCHANT_CATEGORIES.include?(merchant_category)
      end

      def merchant_allowed?
        disallowed_categories = card&.card_grant&.disallowed_categories
        disallowed_merchants = card&.card_grant&.disallowed_merchants

        return false if disallowed_categories&.include?(merchant_category)
        return false if disallowed_merchants&.include?(auth[:merchant_data][:network_id])

        allowed_categories = card&.card_grant&.allowed_categories
        allowed_merchants = card&.card_grant&.allowed_merchants
        keyword_lock = card&.card_grant&.keyword_lock

        has_restrictions = allowed_categories.present? || allowed_merchants.present? || keyword_lock.present?
        return true unless has_restrictions

        return true if allowed_categories&.include?(merchant_category)
        return true if allowed_merchants&.include?(auth[:merchant_data][:network_id])
        return true if keyword_lock.present? && Regexp.new(keyword_lock).match?(auth[:merchant_data][:name])

        false # decline transaction if none of the above match
      end

    end
  end
end
