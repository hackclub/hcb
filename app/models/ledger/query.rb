# frozen_string_literal: true

class Ledger
  class Query
    PERMITTED_COLUMNS_MAP = %w[
      memo
      amount_cents
      datetime
      receipt_required
      receipt_count
      linked_object_type
      marked_no_or_lost_receipt_at
      author
    ].index_by(&:itself).freeze

    DATETIME_COLUMNS = %w[
      datetime
      marked_no_or_lost_receipt_at
    ].freeze

    # Query hashes are untrusted input (they can be constructed client-side), so
    # bound their shape: cap nesting depth, the number of predicate groups, and
    # the length of any array (e.g. a $in list) so a deeply-nested, very wide, or
    # very long query can't recurse unbounded or build pathologically large SQL.
    MAX_QUERY_DEPTH = 20
    MAX_QUERY_CONDITIONS = 200
    MAX_ARRAY_LENGTH = 1_000

    class Error < ArgumentError; end

    def initialize(query_hash)
      raise Ledger::Query::Error.new("Query must be a Hash") unless query_hash.is_a?(Hash)

      @query_hash = self.class.sanitize_query(query_hash)

      # TODO: handle authorization
    end

    # Expected to return an ActiveRecord::Relation of Ledger::Item.
    #
    # Querying across every ledger must be opted into explicitly via
    # all_ledgers: true (admin only). Otherwise results are always scoped to the
    # given ledgers — an empty collection returns nothing, so a caller passing a
    # dynamically-empty set (e.g. an event with no card grants) can never leak
    # another organization's items.
    def execute(ledgers: [], all_ledgers: false)
      results = apply_query(relation: Ledger::Item.all, query: @query_hash)

      # Strict boolean: only a literal true opts out of scoping, so a caller that
      # accidentally passes a truthy value (e.g. the string "false") fails closed.
      unless all_ledgers == true
        # Scope via a subquery rather than joins(...).distinct: DISTINCT breaks
        # under Postgres when combined with our ORDER BY and a narrowed select
        # list (e.g. pluck) — ORDER BY expressions must appear in the select list.
        results = results.where(id: Ledger::Mapping.where(ledger_id: ledgers).select(:ledger_item_id))
      end

      # preload, not includes: linked_object is polymorphic, so it can never be
      # JOINed — and includes makes pluck/count attempt exactly that join
      # (EagerLoadPolymorphicError).
      results.order(datetime: :desc, created_at: :desc, id: :desc).preload(:linked_object)
    end

    def self.sanitize_query(query_hash)
      # TODO: Implement query sanitization logic
      validate_complexity!(query_hash)
      query_hash
    end

    # Walks the query tree once, bounding nesting depth, the number of predicate
    # groups (Hash nodes), and array length. Counting Hash nodes rather than
    # every scalar means a $in list is bounded by its length (MAX_ARRAY_LENGTH)
    # rather than the condition cap, so a legitimately sized $in isn't penalized.
    def self.validate_complexity!(node, depth = 1, condition_count = [0])
      raise Ledger::Query::Error.new("Query is nested too deep (max depth #{MAX_QUERY_DEPTH})") if depth > MAX_QUERY_DEPTH

      case node
      when Hash
        condition_count[0] += 1
        raise Ledger::Query::Error.new("Query has too many conditions (max #{MAX_QUERY_CONDITIONS})") if condition_count[0] > MAX_QUERY_CONDITIONS

        node.each_value { |value| validate_complexity!(value, depth + 1, condition_count) }
      when Array
        raise Ledger::Query::Error.new("Query array is too large (max #{MAX_ARRAY_LENGTH} elements)") if node.length > MAX_ARRAY_LENGTH

        node.each { |value| validate_complexity!(value, depth + 1, condition_count) }
      end
    end

    private

    def apply_query(relation:, query:, context: "and")
      query.each do |key, value|
        key = key.to_s

        if key.starts_with?("$")
          operator = key[1..]

          case operator
          when "and"
            raise Ledger::Query::Error.new("$#{operator} must be an array") unless value.is_a?(Array)

            value.each do |sub_query|
              relation = apply_query(relation:, query: sub_query)
            end
          when "or"
            raise Ledger::Query::Error.new("$#{operator} must be an array") unless value.is_a?(Array)

            sub_relation = nil

            value.each do |sub_query|
              branch = apply_query(relation: Ledger::Item.all, query: sub_query, context: "and")
              sub_relation = sub_relation.nil? ? branch : sub_relation.or(branch)
            end

            sub_relation ||= Ledger::Item.none

            if context == "and"
              # merge would replace, not AND, existing conditions on the same column
              relation = relation.and(sub_relation)
            else
              relation = relation.or(sub_relation)
            end
          when "nor"
            # $nor negates the union of its branches: NOT (a OR b OR ...). This
            # is MongoDB's top-level negation. (A field-level $not — the only
            # $not MongoDB defines — is handled per-field in apply_partial_predicate.)
            raise Ledger::Query::Error.new("$#{operator} must be an array") unless value.is_a?(Array)

            union = nil
            value.each do |sub_query|
              branch = apply_query(relation: Ledger::Item.all, query: sub_query, context: "and")
              union = union.nil? ? branch : union.or(branch)
            end
            # An empty $nor negates an empty union, i.e. matches everything —
            # consistent with an empty $and (matches all) / empty $or (matches none).
            union ||= Ledger::Item.none

            negated = Ledger::Item.where.not(id: union.select(:id))
            if context == "and"
              relation = relation.and(negated)
            else
              relation = relation.or(negated)
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
      raise Ledger::Query::Error.new("Invalid field name: #{raw_key}") unless key.present?

      operand = coerce_datetime_operand(operand) if DATETIME_COLUMNS.include?(key)

      if operand.is_a?(String) && key == "author"
        case operator.to_s
        when "$eq"
          return relation.where(author: User.where(slug: operand))
        when "$ne"
          return relation.where.not(author: User.where(slug: operand))
        else
          raise Ledger::Query::Error.new("Unsupported comparison operator for author: #{operator}")
        end
      end

      if operand.is_a?(String) && key == "author"
        case operator.to_s
        when "$eq"
          return relation.where(author: User.where(slug: operand))
        when "$ne"
          return relation.where.not(author: User.where(slug: operand))
        else
          raise Ledger::Query::Error.new("Unsupported comparison operator for author: #{operator}")
        end
      end

      col = Ledger::Item.arel_table[key]

      # Dispatch on the operator first, then validate the operand for that
      # operator. Dispatching on the operand's Ruby type instead would make an
      # operator silently change meaning (e.g. $eq of an array becoming IN) or
      # raise a misleading "unsupported operator" for a supported operator given
      # the "wrong" operand type (e.g. $gt on a string). Operator-first keeps the
      # contract "supported for this operand, or a clear error — never silently
      # wrong".
      case operator.to_s
      when "$eq"
        reject_array_operand!(operator, operand)
        relation.where(key => operand)
      when "$ne"
        reject_array_operand!(operator, operand)
        # != drops NULL rows; MongoDB's $ne matches them, so re-include (unless
        # the operand is NULL itself, which means IS NOT NULL).
        if operand.nil?
          relation.where.not(key => nil)
        else
          relation.where.not(key => operand).or(relation.where(key => nil))
        end
      when "$gt"
        relation.where(col.gt(require_comparable_operand!(operator, operand)))
      when "$gte"
        relation.where(col.gteq(require_comparable_operand!(operator, operand)))
      when "$lt"
        relation.where(col.lt(require_comparable_operand!(operator, operand)))
      when "$lte"
        relation.where(col.lteq(require_comparable_operand!(operator, operand)))
      when "$in"
        require_array_operand!(operator, operand)
        relation.where(key => operand)
      when "$nin"
        require_array_operand!(operator, operand)
        # NOT IN drops NULL rows; MongoDB's $nin matches them, so re-include.
        relation.where.not(key => operand).or(relation.where(key => nil))
      when "$not"
        # Field-level $not negates an inner operator expression, e.g.
        # { amount_cents: { $not: { $gt: 100 } } }. Negating via a NOT IN subquery
        # matches rows that fail the inner predicate, including NULL rows (their
        # id is absent from the inner set) — mirroring MongoDB.
        raise Ledger::Query::Error.new("$not requires an operator expression") unless operand.is_a?(Hash)

        inner = operand.reduce(Ledger::Item.all) do |rel, (inner_operator, inner_operand)|
          apply_partial_predicate(rel, inner_operator, raw_key, inner_operand)
        end
        relation.where.not(id: inner.select(:id))
      when "$search"
        # $search is an HCB extension (not a MongoDB operator): pg_search
        # full-text search, supported only on the memo column.
        raise Ledger::Query::Error.new("$search is only supported on the memo field") unless key == "memo"

        relation.where(id: Ledger::Item.search_memo(operand).select(:id))
      else
        raise Ledger::Query::Error.new("Unsupported comparison operator: #{operator}")
      end
    end

    def require_array_operand!(operator, operand)
      raise Ledger::Query::Error.new("#{operator} requires an array operand") unless operand.is_a?(Array)
    end

    def reject_array_operand!(operator, operand)
      raise Ledger::Query::Error.new("#{operator} does not support array operands (use $in / $nin)") if operand.is_a?(Array)
    end

    def require_comparable_operand!(operator, operand)
      # Range comparisons need a single ordered scalar: a number, a string, or a
      # coerced datetime. Arrays, booleans, and nil have no ordering here.
      unless operand.is_a?(Numeric) || operand.is_a?(String) || operand.acts_like?(:date) || operand.acts_like?(:time)
        raise Ledger::Query::Error.new("#{operator} requires a comparable value")
      end

      operand
    end

    def coerce_datetime_operand(operand)
      case operand
      when Array
        operand.map { |value| coerce_datetime_operand(value) }
      when String
        begin
          Time.zone.iso8601(operand)
        rescue ArgumentError
          raise Ledger::Query::Error.new("Invalid ISO 8601 datetime: #{operand}")
        end
      else
        operand
      end
    end

  end

end
