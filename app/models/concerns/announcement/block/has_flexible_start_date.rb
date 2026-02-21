# frozen_string_literal: true

class Announcement
  class Block
    module HasFlexibleStartDate
      extend ActiveSupport::Concern

      def start_date_param
        parameters["start_date"].presence && DateTime.parse(parameters["start_date"])
      end
    end

  end

end
