# frozen_string_literal: true

module Admin
  class AiBlazerQueriesController < BaseController
    before_action :set_query, only: :show

    def index
      @page = params[:page] || 1
      @per = params[:per] || 20
      @queries = Blazer::AiQuery.recent.page(@page).per(@per)
    end

    def new
      @prompt = ""
    end

    def create
      @prompt = query_params.fetch(:prompt)
      generated = Blazer::AiQueryGenerator.new(prompt: @prompt).run!

      @query = Blazer::Query.new(
        name: Blazer::AiQuery.prefixed_name(generated[:name]),
        statement: Blazer::AiQuery.with_prompt_comment(statement: generated[:statement], prompt: @prompt),
        data_source: "main",
        creator_id: current_user.id
      )

      if @query.save
        redirect_to admin_ai_blazer_query_path(@query), flash: { success: "AI query created successfully." }
      else
        flash.now[:error] = @query.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.error.report(e)
      flash.now[:error] = "Unable to generate a query right now."
      render :new, status: :unprocessable_entity
    end

    def show
      @prompt = Blazer::AiQuery.extract_prompt(@query.statement)
      @statement = Blazer::AiQuery.strip_prompt_comment(@query.statement)
    end

    private

    def set_query
      @query = Blazer::Query.find(params[:id])
      raise ActiveRecord::RecordNotFound unless Blazer::AiQuery.ai?(@query)
    end

    def query_params
      params.require(:ai_blazer_query).permit(:prompt)
    end
  end
end
