# frozen_string_literal: true

module RuboCop
  module Cop
    module Hcb
      class TurboConfirm < Base
        MSG = "Use `data: { turbo_confirm: ... }` instead of `data: { confirm: ... }`."

        def on_pair(node)
          return unless symbol_key?(node, :data)
          return unless node.value.hash_type?

          confirm_pair = node.value.pairs.find { |pair| symbol_key?(pair, :confirm) }
          return unless confirm_pair

          add_offense(confirm_pair)
        end

        private

        def symbol_key?(node, key)
          node.key.sym_type? && node.key.value == key
        end

      end
    end
  end
end
