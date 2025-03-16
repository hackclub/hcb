# frozen_string_literal: true

module Freezeable
  extend ActiveSupport::Concern

  included do
    validate on: :create do
      if event.frozen?
        errors.add(:base, "This transfer can't be created, #{event.name} is currently frozen.")
      end
    end
  end
end
