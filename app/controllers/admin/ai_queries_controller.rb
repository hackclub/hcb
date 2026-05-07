# frozen_string_literal: true

module Admin
  class AiQueriesController < BaseController
    before_action :set_ai_query, only: [:show, :destroy]

    def index
      @ai_queries = AiQuery.order(created_at: :desc).includes(:blazer_query, :creator)
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

      @ai_query = AiQuery.create!(prompt:, creator: current_user)
      AiQueryGenerationJob.perform_later(@ai_query.id)

      redirect_to admin_ai_query_path(@ai_query)
    end

    def show
    end

    def destroy
      @ai_query.blazer_query&.destroy
      @ai_query.destroy
      redirect_to admin_ai_queries_path, notice: "Query deleted."
    end

    private

    def set_ai_query
      @ai_query = AiQuery.find(params[:id])
    end
  end
end
