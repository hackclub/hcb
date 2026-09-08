# frozen_string_literal: true

module RuboCop
  module Cop
    module Hcb
      # `link_to ..., method: :post` is Rails-UJS syntax: it renders a plain
      # `<a data-method="post">`. Turbo has no `data-method` support, so the
      # browser follows the link as a GET, the POST-only route doesn't match,
      # and the user gets a bare 404 with nothing logged as an app error.
      #
      # `button_to` and the `form_*` helpers are fine — they emit a real form.
      #
      #   # bad
      #   link_to "Accept invitation", accept_path, method: :post
      #
      #   # good
      #   link_to "Accept invitation", accept_path, data: { turbo_method: :post }
      #
      #   # also good — renders a real <form>
      #   button_to "Accept invitation", accept_path, method: :post
      class TurboMethod < Base
        MSG = "Use `data: { turbo_method: %{verb} }` instead of `method: %{verb}`. " \
              "Turbo ignores `data-method`, so this link falls back to a GET and 404s."

        LINK_HELPERS = %i[link_to pop_icon_to].freeze
        VERBS = %i[post put patch delete].freeze

        def on_send(node)
          return unless LINK_HELPERS.include?(node.method_name)

          options = node.last_argument
          return unless options.respond_to?(:hash_type?) && options.hash_type?

          method_pair = options.pairs.find { |pair| symbol_key?(pair, :method) && verb?(pair.value) }
          return unless method_pair

          add_offense(method_pair, message: format(MSG, verb: method_pair.value.source))
        end

        private

        def symbol_key?(node, key)
          node.key.sym_type? && node.key.value == key
        end

        def verb?(node)
          node.sym_type? && VERBS.include?(node.value)
        end

      end
    end
  end
end
