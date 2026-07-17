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

    @items = begin
      Ledger::Query.new(query_hash).execute(ledgers: [@ledger])
    rescue Ledger::Query::Error => e
      flash.now[:error] = "Query error: #{e.message}"

      Ledger::Query.new({}).execute(ledgers: [@ledger])
    end.preload(hcb_code: [:event, { tags: :event }]).page(params[:page])
  end

end
