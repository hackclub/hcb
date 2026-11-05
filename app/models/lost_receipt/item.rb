# frozen_string_literal: true

module LostReceipt
  class Item
    include ActiveModel::Model

    attr_accessor :description, :quantity, :unit_amount_cents

    validates :description, presence: true, length: { maximum: 255 }
    validates :quantity, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 10_000 }
    validates :unit_amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100_000_000 }

    def unit_amount
      cents = Integer(unit_amount_cents, exception: false)
      Money.new(cents, "USD") unless cents.nil?
    end

    def unit_amount=(value)
      amount = BigDecimal(value.to_s, exception: false)
      self.unit_amount_cents = amount&.finite? ? Money.from_amount(amount, "USD").cents : value
    end

    def total_amount_cents
      quantity.to_i * unit_amount_cents.to_i
    end

  end
end
