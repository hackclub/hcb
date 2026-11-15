# frozen_string_literal: true

# Forked from https://andycroll.com/ruby/prevent-links-in-text-fields-to-foil-spammers/

class NoUrlsValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?

    if value.match?(/(http|\w+\.\w+\/?)/)
      record.errors.add(attribute, options[:message] || "cannot contain a web address")
    end
  end

end
