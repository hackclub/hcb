# frozen_string_literal: true

class Ledger
  class Query
    # Builds an Export over exactly the rows a query matches.
    #
    # The query travels with the export instead of being rebuilt from request
    # params later, so an export taken from a filtered ledger *is* that filtered
    # ledger — including on the async path, where the file is generated in a job
    # long after the request that asked for it is gone.
    class Export
      FORMATS = %i[csv json ledger].freeze

      def initialize(query:, as:, ledgers: [], all_ledgers: false, **attributes)
        @query = query
        @as = as
        @ledgers = ledgers
        @all_ledgers = all_ledgers
        @attributes = attributes
      end

      def run
        export_class.new(
          # as_json so the query round-trips through the exports.parameters jsonb
          # column unchanged (Dates become ISO 8601 strings, symbols become keys).
          query: query.query_hash.as_json,
          ledger_ids:,
          # Strict boolean, matching Ledger::Query#execute: only a literal true
          # opts out of ledger scoping, so a truthy value fails closed.
          all_ledgers: all_ledgers == true,
          **attributes
        )
      end

      # The leading `::` matters: inside this class, a bare `Export` resolves to
      # this class, not to the ActiveRecord model.
      def export_class
        case as.to_s.to_sym
        when :csv
          ::Export::Ledger::Item::Csv
        when :json
          ::Export::Ledger::Item::Json
        when :ledger
          ::Export::Ledger::Item::Journal
        else
          raise Ledger::Query::Error.new("Unsupported export format: #{as}")
        end
      end

      private

      attr_reader :query, :as, :ledgers, :all_ledgers, :attributes

      # Ledgers are stored by id, so the export can be handed to a job.
      def ledger_ids
        Array(ledgers).map { |ledger| ledger.is_a?(::Ledger) ? ledger.id : ledger }
      end

    end

  end

end
