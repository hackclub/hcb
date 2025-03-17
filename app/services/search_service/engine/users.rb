# frozen_string_literal: true

module SearchService
  class Engine
    class Users
      include DynamicFilters

      def initialize(query, user, context)
        @query = query
        @user = user
        @admin = user.admin?
        @context = context
      end

      def run
        if @context[:event_id] && @query["types"].length == 1
          users = Event.find(@context[:event_id]).users.where.not(full_name: nil)
        elsif @admin
          users = User.where.not(full_name: nil)
        else
          users = User.where(id: @user.events.map { |e| e.users.pluck(:id) }.flatten)
        end
        @query["conditions"]&.each do |condition|
          case condition[:property]
          when "date"
            value = Chronic.parse(condition[:value], context: :past)
            filter_by_column(users, :created_at, condition[:operator], value)
          end
        end
        users = users.search_name(@query["query"])
        return users
      end

    end

  end
end
