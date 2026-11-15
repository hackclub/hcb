# frozen_string_literal: true

# NOTE(@lachlanjc and @MaxWofford):
# This concern exists to abstract the multiple statuses of various requests/
# applications for things across the app. Not all models that include Rejectable
# have canceled_at fields, so we made two methods here.
module Rejectable
  extend ActiveSupport::Concern

  def accepted?
    accepted_at.present?
  end

  def rejected?
    rejected_at.present?
  end

  def canceled?
    canceled_at.present?
  end

  def status_accepted_canceled_or_rejected
    single_status %i{accepted_at rejected_at canceled_at}
  end

  def single_status(status_columns)
    columns_with_errors = status_columns.select { |col| self[col].present? }
    if columns_with_errors.size > 1
      columns_with_errors.each do |col|
        other_columns = columns_with_errors - [col]
        errors.add(col, "can’t be present along with #{other_columns}")
      end
    end
  end
end
