# frozen_string_literal: true

class Ledger
  class Query
    def initialize(query_hash)
      @query_hash = self.class.sanitize_query(query_hash)

      # TODO: handle authorization
    end

    # Expected to return an ActiveRecord::Relation of Ledger::Item
    def execute(ledger_id: nil)
      # TODO: (WARNING) We're currently using AR `where` syntax, but WILL change
      apply_query(ledger_id.present? ? Ledger::Item.where(ledger_id: ledger_id) : Ledger::Item, @query_hash)
    end

    def self.sanitize_query(query_hash)
      # TODO: Implement query sanitization logic
      query_hash
    end

    private

    def apply_query(raw_relation, query_hash, context = "and")
      relation = raw_relation.clone

      query_hash.each do |key, value|
        key = key.to_s

        if key.starts_with?("$")
          operator = key[1..]

          if operator == "and"
            value.each do |sub_query|
              relation = apply_query(relation, sub_query)
            end
          elsif operator == "or"
            sub_relation = Ledger::Item.none

            value.each do |sub_query|
              sub_relation = apply_query(sub_relation, sub_query, "or")
            end

            if context == "and"
              relation = relation.merge(sub_relation)
            else
              relation = relation.or(sub_relation)
            end
          elsif operator == "not"
            if context == "and"
              sub_relation = apply_query(Ledger::Item.all, value, "and")
              relation = relation.exclude(sub_relation)
            else
              sub_relation = apply_query(Ledger::Item.none, value, "and")
              relation = relation.or(Ledger::Item.exclude(sub_relation))
            end
          else
            raise Ledger::Query::QueryError.new("Unsupported logical operator: #{operator}")
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

    def sanitize_column(column_name)
      safe_column = Ledger::Item.column_names.find { |col| col == column_name.to_s }

      raise Ledger::Query::QueryError.new("Invalid column name: #{column_name}") unless safe_column.present?
    end

    def apply_partial_predicate(relation, operator, key, operand)
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
      elsif operand.is_a?(String)
        case operator.to_s
        when "$in"
          return relation.where(key => operand)
        when "$nin"
          return relation.where.not(key => operand)
        when "$ilike"
          return relation.where("#{key} ILIKE ?", operand)
        when "$like"
          return relation.where("#{key} ILIKE ?", operand)
        end
      end

      case operator.to_s
      when "$eq"
        relation.where(key => operand)
      when "$ne"
        relation.where.not(key => operand)
      else
        raise Ledger::Query::QueryError.new("Unsupported operator: #{operator}")
      end
    end

  end

end
