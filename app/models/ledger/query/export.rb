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
      # Every format an export can take, and the class that produces it. The
      # leading `::` matters: inside this class, a bare `Export` resolves to
      # this class, not to the ActiveRecord model.
      FORMATS = {
        csv: ::Export::Ledger::Item::Csv,
        json: ::Export::Ledger::Item::Json,
        ledger: ::Export::Ledger::Item::Journal,
      }.freeze

      def initialize(query:, as:, ledgers: [], all_ledgers: false, event_id: nil, requested_by: nil, public_only: false, filtered: false)
        @query = query
        @as = as
        @ledgers = ledgers
        @all_ledgers = all_ledgers
        @event_id = event_id
        @requested_by = requested_by
        @public_only = public_only
        @filtered = filtered
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
          event_id:,
          requested_by:,
          public_only:,
          filtered:
        )
      end

      def export_class
        FORMATS.fetch(as.to_s.to_sym) do
          raise Ledger::Query::Error.new("Unsupported export format: #{as}")
        end
      end

      private

      attr_reader :query, :as, :ledgers, :all_ledgers, :event_id, :requested_by, :public_only, :filtered

      # Ledgers are stored by id, so the export can be handed to a job.
      def ledger_ids
        Array(ledgers).map { |ledger| ledger.is_a?(::Ledger) ? ledger.id : ledger }
      end

    end

  end

end
