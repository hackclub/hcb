# frozen_string_literal: true

module Freezable
  extend ActiveSupport::Concern

  included do
    validate on: :create do
      if event.financially_frozen?
        errors.add(:base, "This transfer can't be created, #{event.name} is currently frozen.")
      end
    end
  end
end
