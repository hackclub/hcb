# frozen_string_literal: true

module Tax
  REPORTING_THRESHOLD_1099 = 600_00
  def self.table_name_prefix
    "tax_"
  end

  def self.year = Date.today.year
end
