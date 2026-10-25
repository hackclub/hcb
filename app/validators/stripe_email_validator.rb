# frozen_string_literal: true

# Stripe rejects emails RFC 5322 (and so validates_email_format_of) permits: quoted or
# commented local parts, IP or single-label domains, and non-ASCII characters.
class StripeEmailValidator < ActiveModel::EachValidator
  ATOM = /[a-z0-9!\#$%&'*+\/=?^_`{|}~-]+/i
  FORMAT = /\A#{ATOM}(\.#{ATOM})*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}\z/i

  def validate_each(record, attribute, value)
    return if value.to_s.match?(FORMAT) && ValidatesEmailFormatOf.validate_email_format(value).nil?

    record.errors.add(attribute, options[:message] || ValidatesEmailFormatOf.default_message)
  end

end
