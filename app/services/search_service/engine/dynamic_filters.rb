# frozen_string_literal: true

module SearchService
  class Engine
    module DynamicFilters
      VALID_COMPARISON_OPERATORS = {
        ">"  => :gt,
        "<"  => :lt,
        "="  => :eq,
        ">=" => :gteq,
        "<=" => :lteq
      }.freeze

      def filter_by_column(relation, column, operator, value)
        filter_by_arel_node(relation, relation.arel_table[column], operator, value)
      end

      def filter_by_arel_node(relation, arel_node, operator, value)
        operator = VALID_COMPARISON_OPERATORS.fetch(operator)
        relation.where(
          arel_node.send(operator, Arel::Nodes::BindParam.new(value))
        )
      end

    end

  end
end
