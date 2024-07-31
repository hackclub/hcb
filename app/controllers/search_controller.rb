# frozen_string_literal: true

class SearchController < ApplicationController
  skip_after_action :verify_authorized # do not force pundit
  # GET /search
  def index
    begin
      raise Errors::ValidationError, "Please provide a query parameter." unless params[:query]

      query = SearchService::Parser.new(params[:query]).run
      results = SearchService::Authorizer.new(
        SearchService::Engine.new(query, current_user).run,
        current_user
      ).run

      render json: SearchService::Formatter.new(results).run
    rescue Errors::ValidationError => e
      # Handle any validation errors
      render json: { error: e.message }
    end
  end

end
