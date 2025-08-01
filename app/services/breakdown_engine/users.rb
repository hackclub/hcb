# frozen_string_literal: true

module BreakdownEngine
  class Users
    def initialize(event, show_all: false, start_date: nil, end_date: Time.now)
      @event = event
      @show_all = show_all
      @start_date = start_date
      @end_date = end_date
    end

    def run
      users = @event.organizer_positions.includes(:user)
                    .each_with_object([]) do |position, array|
        amount = @event.canonical_transactions
                       .stripe_transaction
                       .joins("JOIN stripe_cardholders ON raw_stripe_transactions.stripe_transaction->>'cardholder' = stripe_cardholders.stripe_id")
                       .where({
                         stripe_cardholders: {
                           user_id: position.user.id
                         },
                         raw_stripe_transactions: @start_date.present? || @end_date.present? ? { created_at: @start_date..@end_date } : nil
                       }.compact)
                       .sum(:amount_cents).to_f / 100 * -1

        next unless !@show_all && amount > 0

        array << { name: position.user.initial_name, truncated: position.user.initial_name, value: amount, position: }
      end

      # Sort by amount in descending order
      users.sort_by! { |user| -user[:value] }

      # Limit to top 11 users
      users.first(11)
    end

  end
end
