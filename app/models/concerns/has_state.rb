# frozen_string_literal: true

# Provides a standardized interface for stateful models.
#
# Every including model should define:
#   - state_color: the CSS color class for the state badge (e.g. "success", "info", "error")
#   - state_icon (optional): an icon name to display alongside the badge (e.g. "checkmark")
#
# state returns the raw AASM state as a symbol for AASM models, and raises
# NotImplementedError for non-AASM models that don't override it.
module HasState
  extend ActiveSupport::Concern

  def state
    if respond_to?(:aasm_state)
      aasm_state.to_sym
    else
      raise NotImplementedError, "#{self.class} must implement #state"
    end
  end

  def state_color
    raise NotImplementedError, "#{self.class} must implement #state_color"
  end

  def state_icon
    nil
  end
end
