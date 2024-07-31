# frozen_string_literal: true

module SearchService
  class Authorizer
    def initialize(results, user)
      @results = results
      @user = user
    end

    def run
      @results.filter { |result| Pundit.policy(@user, result).show? }
    end

  end
end
