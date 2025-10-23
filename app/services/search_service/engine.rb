# frozen_string_literal: true

module SearchService
  class Engine
    def initialize(queries, user)
      @queries = queries
      @user = user
      @context = {
        event_id: nil,
        user_id: nil,
        card_stripe_id: nil
      }
    end

    def run
      results = []
      @queries.each do |query|
        results = []
        query["types"].each do |type|
          case type
          when "card"
            cards = SearchService::Engine::Cards.new(query, @user, @context).run
            unless query["types"].length > 1 && (@context[:event_id] || @context[:user_id])
              @context[:card_stripe_id] = cards.first&.stripe_id
            end
            results.concat(cards)
          when "user"
            users = SearchService::Engine::Users.new(query, @user, @context).run
            unless query["types"].length > 1 && @context[:event_id]
              @context[:user_id] = users.first&.id
            end
            results.concat(users)
          when "organization"
            events = SearchService::Engine::Events.new(query, @user, @context).run
            @context[:event_id] = events.first&.id
            results.concat(events)
          when "transaction"
            results.concat(SearchService::Engine::Transactions.new(query, @user, @context).run)
          when "reimbursement"
            results.concat(SearchService::Engine::Reimbursements.new(query, @user, @context).run)
          end
        end
      end
      return results
    end

  end
end
