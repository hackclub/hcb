# frozen_string_literal: true

class ColumnService
  module Uetr
    # https://docs.column.com/api/international-wire/get-international-wire-tracking
    def self.lookup(uetr)
      Rails.cache.fetch("column_uetr_tracking_#{uetr}", expires_in: 5.minutes) do
        ColumnService.get("/transfers/international-wire/#{uetr}/tracking")
      end
    end

  end

end
