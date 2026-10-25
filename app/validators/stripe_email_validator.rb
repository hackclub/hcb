# frozen_string_literal: true

# Stripe rejects emails that pass RFC checks: quoted or commented local parts, whitespace, non-ASCII.
# Catching them here keeps an invalid email from surfacing as a Stripe::InvalidRequestError.
#
#   validates :email, stripe_email: true
class StripeEmailValidator < ActiveModel::EachValidator
  FORMAT = /\A[a-z0-9!#$%&'*+\/=?^_`{|}~.-]+@[a-z0-9.-]+\z/i

  def validate_each(record, attribute, value)
    return if value.match?(FORMAT) && ValidatesEmailFormatOf.validate_email_format(value).nil?

    record.errors.add(attribute, options[:message] || ValidatesEmailFormatOf.default_message)
  end

end
