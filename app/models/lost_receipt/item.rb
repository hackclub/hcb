# frozen_string_literal: true

module LostReceipt
  class Item < ApplicationRecord
    belongs_to :statement, inverse_of: :items

    monetize :unit_amount_cents, as: :unit_amount

    validates :description, presence: true, length: { maximum: 255 }
    validates :quantity, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 10_000 }
    validates :unit_amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100_000_000 }

    def total_amount_cents
      quantity * unit_amount_cents
    end

  end
end
