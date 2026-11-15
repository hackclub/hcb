# frozen_string_literal: true

# SafeCsv - A wrapper around CSV::Row that sanitizes values by default
# to prevent CSV formula injection attacks.
#
# Usage:
#   SafeCsv::Row.new(headers, values)  # Values are automatically sanitized
#   SafeCsv::Row.new(headers, values, sanitize: false)  # Opt-out if needed
#
module SafeCsv
  class Row < CSV::Row
    # rubocop:disable Style/OptionalBooleanParameter
    def initialize(headers, fields, header_row = false, sanitize: true)
      sanitized_fields = if sanitize
                           fields.map { |field| SafeCsv.sanitize(field) }
                         else
                           fields
                         end
      super(headers, sanitized_fields, header_row)
    end
    # rubocop:enable Style/OptionalBooleanParameter

  end

  # Sanitizes a value to prevent CSV/Excel formula injection
  # Prepends a single quote if the value starts with dangerous characters
  def self.sanitize(value)
    return value if value.nil?
    return value unless value.is_a?(String) || value.is_a?(Symbol)

    string_value = value.to_s
    return value if string_value.empty?

    # Allow valid numbers (including negative and positive with explicit sign)
    # Examples: -8, -8.50, +5, +10.25
    return value if string_value.match?(/\A[+-]?\d+(\.\d+)?\z/)

    # Check if the value starts with dangerous characters
    # =  Formula (e.g., =1+1, =SUM(A1:A10))
    # +  Formula (e.g., +1+1)
    # -  Formula (e.g., -1+1)
    # @  Lotus 1-2-3 formula (e.g., @SUM(A1:A10))
    # |  Pipe character (e.g., =cmd|'/c calc'!A1)
    # \t Tab character followed by formula
    if string_value.match?(/\A[=+\-@|\t]/)
      "'#{string_value}"
    else
      value
    end
  end
end
