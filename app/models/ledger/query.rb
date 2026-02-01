# frozen_string_literal: true

class Ledger < ApplicationRecord
  class Query
    def initialize(ledger_ids, query_hash)
      @ledger_ids = ledger_ids
      @query_hash = self.class.sanitize_query(query_hash)

      # TODO: handle authorization
    end

    # Expected to return an ActiveRecord::Relation of Ledger::Item
    def execute
      # TODO: (WARNING) We're currently using AR `where` syntax, but WILL change
      Ledger::Item.where(ledger_id: @ledger_ids).where(@query_hash)
    end

    def self.sanitize_query(query_hash)
      # TODO: Implement query sanitization logic
      query_hash
    end

  end

end
