# frozen_string_literal: true

# == Schema Information
#
# Table name: lost_receipt_items
#
#  id                :bigint           not null, primary key
#  description       :string           not null
#  quantity          :integer          not null
#  unit_amount_cents :integer          not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  statement_id      :bigint           not null
#
# Indexes
#
#  index_lost_receipt_items_on_statement_id  (statement_id)
#
# Foreign Keys
#
#  fk_rails_...  (statement_id => lost_receipt_statements.id)
#
module LostReceipt
  # One line of a lost receipt statement.
  class Item < ApplicationRecord
    belongs_to :statement, inverse_of: :items

    validates :description, presence: true, length: { maximum: 255 }
    validates :quantity, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 10_000 }
    validates :unit_amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100_000_000 }

    def unit_amount
      Money.new(unit_amount_cents, "USD") unless unit_amount_cents.nil?
    end

    # A JSON body can carry an integer millions of digits long, which takes seconds to print back on the form.
    def quantity=(value)
      super(within_bounds(value))
    end

    # The form takes dollars. Anything that isn't a number, or is absurdly large ("1e999999"
    # would become a million-digit integer), is left nil for validation to reject.
    def unit_amount=(value)
      amount = BigDecimal(within_bounds(value).to_s, exception: false)
      self.unit_amount_cents = (Money.from_amount(amount, "USD").cents if amount&.finite? && amount.abs < 1_000_000_000)
    end

    def total_amount_cents
      quantity.to_i * unit_amount_cents.to_i
    end

    private

    def within_bounds(value)
      value unless value.is_a?(Integer) && value.abs > 10**12
    end

  end
end
