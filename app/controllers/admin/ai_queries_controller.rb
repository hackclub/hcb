# frozen_string_literal: true

module Admin
  class AiQueriesController < BaseController
    before_action :set_query, only: [:show, :destroy]

    def index
      @queries = Blazer::Query
        .where("name LIKE ?", "#{Admin::GenerateAiQuery::AI_QUERY_PREFIX}%")
        .order(created_at: :desc)
    end

    def new
      @prompt = params[:prompt]
    end

    def create
      prompt = params[:prompt].to_s.strip

      if prompt.blank?
        flash.now[:error] = "Please enter a prompt."
        return render :new, status: :unprocessable_entity
      end

      result = Admin::GenerateAiQuery.new(prompt:, user: current_user).run

      if result.success?
        redirect_to admin_ai_query_path(result.query), notice: "Query generated successfully!"
      else
        flash.now[:error] = result.error
        @prompt = prompt
        render :new, status: :unprocessable_entity
      end
    end

    def show
    end

    def destroy
      @query.destroy
      redirect_to admin_ai_queries_path, notice: "Query deleted."
    end

    private

    def set_query
      @query = Blazer::Query
        .where("name LIKE ?", "#{Admin::GenerateAiQuery::AI_QUERY_PREFIX}%")
        .find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_ai_queries_path, alert: "Query not found."
    end
  end
end
