# frozen_string_literal: true

module Errors
  class InvalidLoginCode < StandardError
  end

  class ValidationError < StandardError
  end

  class InvalidStripeCardLogoError < StandardError
  end

  class StripeIssuingBalanceAnomaly < StandardError
  end

end
