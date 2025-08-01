# frozen_string_literal: true

class Announcement
  class Block
    module HasEndDate
      extend ActiveSupport::Concern

      included do
        before_create :end_date_param
      end

      def end_date_param
        if self.parameters["end_date"].present?
          DateTime.parse(self.parameters["end_date"])
        else
          self.parameters["end_date"] ||= Time.now.to_s
          Time.now
        end
      end
    end

  end

end
