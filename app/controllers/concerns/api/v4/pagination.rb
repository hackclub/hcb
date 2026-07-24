# frozen_string_literal: true

module Api
  module V4
    module Pagination
      extend ActiveSupport::Concern

      included do
        private

        def paginate_cursor(list, &block)
          limit = params[:limit]&.to_i || 25
          return render json: { error: "invalid_operation", messages: ["Limit is capped at 100. '#{params[:limit]}' is invalid."] }, status: :bad_request if limit > 100

          start_index = if params[:after]
                          index = list.index { |item| block.call(item) == params[:after] }
                          return render json: { error: "invalid_operation", messages: ["After parameter '#{params[:after]}' not found"] }, status: :bad_request if index.nil?

                          index + 1
                        else
                          0
                        end

          paged = Kaminari.paginate_array(list).page(1).per(limit).padding(start_index)
          @total_count = paged.total_count
          @has_more = paged.next_page.present?
          paged.to_a
        end

        # Keyset (seek) pagination for an ActiveRecord::Relation. Unlike
        # #paginate_cursor, this never loads the full result set into memory: the
        # cursor (a public_id) is resolved to its sort key and the page is fetched
        # directly in SQL with a LIMIT. `column` must be a real column on the
        # relation's table
        def paginate_relation(relation, column: :created_at, direction: :desc)
          limit = params[:limit]&.to_i || 25
          return render json: { error: "invalid_operation", messages: ["Limit is capped at 100. '#{params[:limit]}' is invalid."] }, status: :bad_request if limit > 100

          seek = relation
          if params[:after].present?
            cursor = relation.klass.find_by_public_id(params[:after])
            return render json: { error: "invalid_operation", messages: ["After parameter '#{params[:after]}' not found"] }, status: :bad_request if cursor.nil?

            table = relation.table_name
            operator = direction == :desc ? "<" : ">"
            seek = relation.where("(#{table}.#{column}, #{table}.id) #{operator} (?, ?)", cursor.public_send(column), cursor.id)
          end

          records = seek.reorder(column => direction, id: direction).limit(limit + 1).to_a
          @has_more = records.size > limit
          @total_count = relation.count
          records.first(limit)
        end
      end
    end
  end
end
