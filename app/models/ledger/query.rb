# frozen_string_literal: true

class Ledger
  class Query
    PERMITTED_COLUMNS_MAP = %w[memo amount_cents date].index_by(&:to_s).freeze

    class Error < ArgumentError; end

    def initialize(query_hash)
      raise Ledger::Query::Error.new("Query must be a Hash") unless query_hash.is_a?(Hash)

      @query_hash = self.class.sanitize_query(query_hash)

      # TODO: handle authorization
    end

    # Expected to return an ActiveRecord::Relation of Ledger::Item
    def execute(ledgers: [])
      results = apply_query(relation: Ledger::Item.all, query: @query_hash)

      if ledgers.any?
        results = results.merge(Ledger::Item.joins(:ledger_mappings).where(ledger_mappings: { ledger_id: ledgers }).distinct)
      end

      results
    end

    def self.sanitize_query(query_hash)
      # TODO: Implement query sanitization logic
      query_hash
    end

    private

    def apply_query(relation:, query:, context: "and")
      query.each do |key, value|
        key = key.to_s

        if key.starts_with?("$")
          operator = key[1..]

          case operator
          when "and"
            value.each do |sub_query|
              relation = apply_query(relation:, query: sub_query)
            end
          when "or"
            sub_relation = nil

            value.each do |sub_query|
              branch = apply_query(relation: Ledger::Item.all, query: sub_query, context: "and")
              sub_relation = sub_relation.nil? ? branch : sub_relation.or(branch)
            end

            sub_relation ||= Ledger::Item.none

            if context == "and"
              relation = relation.merge(sub_relation)
            else
              relation = relation.or(sub_relation)
            end
          when "not"
            sub_relation = apply_query(relation: Ledger::Item.all, query: value, context: "and")
            if context == "and"
              relation = relation.where.not(id: sub_relation.select(:id))
            else
              relation = relation.or(Ledger::Item.where.not(id: sub_relation.select(:id)))
            end
          else
            raise Ledger::Query::Error.new("Unsupported logical operator: #{operator}")
          end

        else
          relation = apply_predicate(relation, key, value, context)
        end
      end

      relation
    end

    def apply_predicate(raw_relation, key, value, context)
      relation = raw_relation.clone

      if context == "and"
        if value.is_a?(Hash)
          value.each do |operator, operand|
            relation = apply_partial_predicate(relation, operator, key, operand)
          end
        else
          relation = apply_partial_predicate(relation, "$eq", key, value)
        end
      else
        if value.is_a?(Hash)
          value.each do |operator, operand|
            relation = relation.or(apply_partial_predicate(Ledger::Item, operator, key, operand))
          end
        else
          relation = relation.or(apply_partial_predicate(Ledger::Item, "$eq", key, value))
        end
      end

      relation
    end

    def apply_partial_predicate(relation, operator, raw_key, operand)
      key = PERMITTED_COLUMNS_MAP[raw_key]
      raise Ledger::Query::Error.new("Invalid column name: #{raw_key}") unless key.present?

      if operand.is_a?(Numeric)
        case operator.to_s
        when "$gt"
          return relation.where("#{key} > ?", operand)
        when "$lt"
          return relation.where("#{key} < ?", operand)
        when "$gte"
          return relation.where("#{key} >= ?", operand)
        when "$lte"
          return relation.where("#{key} <= ?", operand)
        end
      elsif operand.is_a?(Array)
        case operator.to_s
        when "$in"
          return relation.where(key => operand)
        when "$nin"
          return relation.where.not(key => operand)
        end
      end

      case operator.to_s
      when "$eq"
        relation.where(key => operand)
      when "$ne"
        relation.where.not(key => operand)
      else
        raise Ledger::Query::Error.new("Unsupported comparison operator: #{operator}")
      end
    end

  end

end
