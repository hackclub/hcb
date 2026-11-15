# frozen_string_literal: true

module Governance
  class Error < StandardError; end

  def self.table_name_prefix
    "governance_"
  end
end
