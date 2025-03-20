# frozen_string_literal: true

module SearchService
  class Engine
    class Cards
      def initialize(query, user, context)
        @query = query
        @user = user
        @admin = user.admin?
        @context = context
      end

      def run
        if @admin
          cards = StripeCard.joins(stripe_cardholder: :user)
        else
          cards = StripeCard.where(event: @user.events).joins(stripe_cardholder: :user)
        end
        cards = cards.where(
          "users.full_name ILIKE :query OR users.email ILIKE :query OR stripe_cards.last4 ILIKE :query",
          query: "%#{User.sanitize_sql_like(@query['query'])}%"
        ).order("stripe_cards.created_at desc")
        cards = cards.where("users.id = ?", @context[:user_id]) if @context[:user_id]
        cards = cards.where("event_id = ?", @context[:event_id]) if @context[:event_id]
        return cards
      end

    end

  end
end
