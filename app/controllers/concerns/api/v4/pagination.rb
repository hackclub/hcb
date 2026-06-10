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
      end
    end
  end
end