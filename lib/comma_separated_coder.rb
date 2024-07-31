# frozen_string_literal: true

class CommaSeparatedCoder
  def self.load(value)
    value&.strip&.split(/,\s*/) || []
  end

  def self.dump(value)
    if value.is_a?(Array)
      value.join(",")
    elsif value.is_a?(String)
      value
    end.strip
  end

end
