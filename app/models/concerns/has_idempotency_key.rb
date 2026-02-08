# frozen_string_literal: true

module HasIdempotencyKey
  extend ActiveSupport::Concern

  included do
    validates :idempotency_key, uniqueness: { message: "This transfer has already been submitted." }, allow_nil: true
  end
end
