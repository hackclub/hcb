# frozen_string_literal: true

module TouchHistory
  extend ActiveSupport::Concern

  included do
    after_touch { @_was_touched = true }

    def was_touched? = @_was_touched
  end
end
