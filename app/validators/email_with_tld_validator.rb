# frozen_string_literal: true

# Validates that an email address is well-formed AND has a TLD in the domain.
# Stripe requires email addresses to have a TLD (e.g. user@example.com),
# but URI::MailTo::EMAIL_REGEXP allows bare domains (e.g. user@localhost).
class EmailWithTldValidator < ActiveModel::EachValidator
  # Requires at least one dot after the @ sign, ensuring a TLD is present.
  TLD_REGEXP = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

  def validate_each(record, attribute, value)
    unless value.match?(URI::MailTo::EMAIL_REGEXP) && value.match?(TLD_REGEXP)
      record.errors.add(attribute, options[:message] || "must be a valid email address with a domain")
    end
  end
end
