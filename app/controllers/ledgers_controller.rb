# frozen_string_literal: true

class LedgersController < ApplicationController
  def show
    @ledger = Ledger.find_by_hashid!(params[:id])
    authorize @ledger

    query_hash = {}
    if auditor_signed_in? && params[:query].present?
      begin
        query_hash = JSON.parse(params[:query])
      rescue JSON::ParserError => e
        flash.now[:error] = "Invalid query JSON: #{e.message}"
      end
    end

    begin
      @items = Ledger::Query.new(query_hash).execute(ledgers: [@ledger]).order(datetime: :desc, created_at: :desc, id: :desc).page(params[:page])
    rescue Ledger::Query::Error => e
      flash.now[:error] = "Query error: #{e.message}"
      @items = Ledger::Query.new({}).execute(ledgers: [@ledger]).order(datetime: :desc, created_at: :desc, id: :desc).page(params[:page])
    end
  end

end
