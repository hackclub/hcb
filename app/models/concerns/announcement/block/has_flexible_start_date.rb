# frozen_string_literal: true

class Announcement
  class Block
    module HasFlexibleStartDate
      extend ActiveSupport::Concern

      def start_date_param
        self.parameters["start_date"].present? ? DateTime.parse(self.parameters["start_date"]) : nil
      end
    end

  end

end
