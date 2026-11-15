# frozen_string_literal: true

class Wire
  module UETR
    FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
    COLUMN_TRANSFER_ID_FORMAT = /\A[a-z]+_[A-Za-z0-9]+\z/

    # Column's tracking endpoint accepts either a UETR or a Column transfer ID.
    def self.valid?(uetr)
      uetr.to_s.match?(FORMAT) || uetr.to_s.match?(COLUMN_TRANSFER_ID_FORMAT)
    end

    # https://docs.column.com/api/international-wire/get-international-wire-tracking
    def self.lookup(uetr)
      Rails.cache.fetch("column_uetr_tracking_#{uetr}", expires_in: 5.minutes) do
        ColumnService.get("/transfers/international-wire/#{uetr}/tracking")
      end
    end

  end

end
