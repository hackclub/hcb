# frozen_string_literal: true

module Api
  module V4
    module Pagination
      extend ActiveSupport::Concern

      included do
        private

        def paginate_cursor(list, &block)
          limit = params[:limit]&.to_i || 25
          raise ArgumentError, "Limit is capped at 100. '#{params[:limit]}' is invalid." if limit > 100

          start_index = if params[:after]
                          index = list.index { |item| block.call(item) == params[:after] }
                          raise ArgumentError, "After parameter '#{params[:after]}' not found" if index.nil?

                          index + 1
                        else
                          0
                        end

          paged = Kaminari.paginate_array(list).page(1).per(limit).padding(start_index)
          @total_count = paged.total_count
          @has_more = paged.next_page.present?
          paged.to_a
        end
      end
    end
  end
end
