# frozen_string_literal: true

module BreakdownEngine
  class Users
    def initialize(event, show_all: false)
      @event = event
      @show_all = show_all
    end

    def run
      @event.organizer_positions.includes(:user)
            .each_with_object([]) do |position, array|
        amount = @event.canonical_transactions
                       .stripe_transaction
                       .joins("JOIN stripe_cardholders ON raw_stripe_transactions.stripe_transaction->>'cardholder' = stripe_cardholders.stripe_id")
                       .where(stripe_cardholders: {
                                user_id: position.user.id
                              })
                       .sum(:amount_cents).to_f / 100 * -1

        next unless !@show_all && amount > (0)

        array << { name: position.user.initial_name, truncated: position.user.initial_name, value: amount, position: }

        array.sort_by! { |user| user[:value] }.reverse!
        total_amount = array.sum { |user| user[:value] }
        threshold = total_amount * 0.05

        next unless threshold > 0

        # Update tags to apply the threshold condition
        array = array.map do |user|
          {
            name: user[:name],
            truncated: user[:truncated],
            value: (user[:value] >= threshold ? user[:value] : 0)
          }
        end

        # Calculate "Other" amount
        other_amount = total_amount - array.sum { |user| user[:value] }
        next unless other_amount > 0

        array << {
          name: "Other",
          truncated: "Other",
          value: other_amount
        }
      end
    end

  end
end
