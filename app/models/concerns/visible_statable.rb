# frozen_string_literal: true

module VisibleStatable
  extend ActiveSupport::Concern

  def visible_state
    self.class.resolve_visible_state(aasm_state)&.to_s || aasm_state
  end

  class_methods do
    def set_visible_state_mapping(mapping)
      @visible_state_mapping = mapping.transform_keys(&:to_sym).transform_values(&:to_sym)
    end

    def visible_state_mapping
      @visible_state_mapping || {}
    end

    def resolve_visible_state(internal_state)
      visible_state_mapping[internal_state.to_sym]
    end

    def filter_by_visible_state(state)
      state_sym = state.to_sym

      internal_states = visible_state_mapping.keys.select { |internal| resolve_visible_state(internal) == state_sym }

      masked = false
      if aasm.states.map(&:name).include?(state_sym)
        masked = visible_state_mapping.key?(state_sym) && resolve_visible_state(state_sym) != state_sym
        internal_states |= [state_sym] unless masked
      end

      internal_states = [state_sym] if internal_states.empty? && !masked

      where(aasm_state: internal_states)
    end
  end
end
