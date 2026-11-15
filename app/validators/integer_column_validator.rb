# frozen_string_literal: true

# Rejects integer values that won't fit in their database column, before they reach Postgres
# on save (which would otherwise raise ActiveModel::RangeError -> 500). The range is derived
# from the column's byte size, so the limit never has to be hardcoded.
#
#   validates :amount_cents, integer_column: true
class IntegerColumnValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.nil?

    column = record.class.columns_hash[attribute.to_s]
    return unless column&.type == :integer

    bits = (column.limit || 4) * 8
    if value > 2**(bits - 1) - 1
      record.errors.add(attribute, "is too big")
    elsif value < -(2**(bits - 1))
      record.errors.add(attribute, "is too small")
    end
  end

end
