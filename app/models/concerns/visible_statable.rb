# frozen_string_literal: true

module VisibleStatable
  extend ActiveSupport::Concern

  def visible_state
    self.class.resolve_visible_state(aasm_state, self.class.visible_state_context&.call(self))&.to_s || aasm_state
  end

  class_methods do
    # Mapping values may be a symbol, or a proc `->(context) { ... }` when the
    # visible state depends on some context (e.g. can_front_balance? on the record's event).
    def set_visible_state_mapping(mapping)
      @visible_state_mapping = mapping.transform_keys(&:to_sym).transform_values { |v| v.respond_to?(:call) ? v : v.to_sym }
    end

    def visible_state_mapping
      @visible_state_mapping || {}
    end

    # Declares how to derive the context object passed to mapping procs from an instance,
    # e.g. `set_visible_state_context { |donation| donation.event }`.
    def set_visible_state_context(&block)
      @visible_state_context = block
    end

    def visible_state_context
      @visible_state_context
    end

    def resolve_visible_state(internal_state, context = nil)
      visible = visible_state_mapping[internal_state.to_sym]
      visible.respond_to?(:call) ? visible.call(context) : visible
    end

    def filter_by_visible_state(state, context: nil)
      state_sym = state.to_sym

      internal_states = visible_state_mapping.keys.select { |internal| resolve_visible_state(internal, context) == state_sym }

      masked = false
      if aasm.states.map(&:name).include?(state_sym)
        masked = visible_state_mapping.key?(state_sym) && resolve_visible_state(state_sym, context) != state_sym
        internal_states |= [state_sym] unless masked
      end

      internal_states = [state_sym] if internal_states.empty? && !masked

      where(aasm_state: internal_states)
    end
  end
end
