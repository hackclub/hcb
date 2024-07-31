# frozen_string_literal: true

module SearchService
  class Engine
    class Events
      def initialize(query, user, context)
        @query = query
        @user = user
        @admin = user.admin?
        @context = context
      end

      def run
        if @context[:user_id] && @query["types"].length == 1
          events = User.find(@context[:user_id]).events
        elsif @admin
          events = Event
        else
          events = @user.events
        end
        @query["conditions"]&.each do |condition|
          case condition[:property]
          when "date"
            value = Chronic.parse(condition[:value], context: :past)
            events = events.where("created_at #{condition[:operator]} ?", value)
          end
        end
        events = events.search_name(@query["query"])
        return events.with_attached_logo.first(20)
      end

    end

  end
end
