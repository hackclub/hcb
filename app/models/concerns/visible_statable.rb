# frozen_string_literal: true

module VisibleStatable
  extend ActiveSupport::Concern

  def visible_state
    self.class.resolve_visible_state(aasm_state, event)&.to_s || aasm_state
  end

  class_methods do
    # Mapping values may be a symbol, or a proc `->(event) { ... }` when the
    # visible state depends on the record's event (e.g. can_front_balance?).
    def set_visible_state_mapping(mapping)
      @visible_state_mapping = mapping.transform_keys(&:to_sym).transform_values { |v| v.respond_to?(:call) ? v : v.to_sym }
    end

    def visible_state_mapping
      @visible_state_mapping || {}
    end

    def resolve_visible_state(internal_state, event = nil)
      visible = visible_state_mapping[internal_state.to_sym]
      visible.respond_to?(:call) ? visible.call(event) : visible
    end

    def filter_by_visible_state(state, event: nil)
      state_sym = state.to_sym

      internal_states = visible_state_mapping.keys.select { |internal| resolve_visible_state(internal, event) == state_sym }

      if aasm.states.map(&:name).include?(state_sym)
        masked = visible_state_mapping.key?(state_sym) && resolve_visible_state(state_sym, event) != state_sym
        internal_states |= [state_sym] unless masked
      end

      raise ArgumentError, "invalid state" if internal_states.empty?

      where(aasm_state: internal_states)
    end
  end
end
