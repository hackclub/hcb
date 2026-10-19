# frozen_string_literal: true

# Rejects strings that can't be compiled into a Regexp, such as merchant name
# (keyword) locks, which are later matched with Regexp.new during authorization.
#
#   validates :keyword_lock, regexp: true
class RegexpValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?

    Regexp.new(value)
  rescue RegexpError
    record.errors.add(attribute, options[:message] || "is not a valid regular expression")
  end

end
