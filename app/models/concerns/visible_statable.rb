# frozen_string_literal: true

module VisibleStatable
  extend ActiveSupport::Concern

  def visible_state
    self.class.visible_state_mapping[aasm_state.to_sym]&.to_s || aasm_state
  end

  class_methods do
    def set_visible_state_mapping(mapping)
      @visible_state_mapping = mapping.transform_keys(&:to_sym).transform_values(&:to_sym)
    end

    def visible_state_mapping
      @visible_state_mapping || {}
    end

    def filter_by_visible_state(state)
      state_sym = state.to_sym

      raise ArgumentError, "invalid state" if visible_state_mapping.key?(state_sym)

      internal_states = visible_state_mapping.filter_map { |internal, visible| internal if visible == state_sym }
      internal_states << state_sym if aasm.states.map(&:name).include?(state_sym)

      raise ArgumentError, "invalid state" if internal_states.empty?

      where(aasm_state: internal_states)
    end
  end
end
