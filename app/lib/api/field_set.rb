# frozen_string_literal: true

module Api
  # Emits JSON fields, but only those the record's policy says this user may
  # see. Serializers write through a FieldSet instead of writing to `json`
  # directly, which makes attribute-level authorization deny-by-default:
  #
  #   object_shape(json, ach_transfer) do |f|
  #     f.recipient_name ach_transfer.recipient_name
  #     f.account_number_last4 { ach_transfer.account_number.slice(-4, 4) }
  #     f.nest(:sender) { json.partial! "api/v5/users/user", user: ach_transfer.creator }
  #   end
  #
  # A field the policy doesn't list is silently skipped — the failure mode of a
  # forgotten declaration is a missing key, not a leak. The block form defers
  # the value, so a hidden field's value is never computed (worth having when
  # computing it means decrypting a column or hitting an external service).
  class FieldSet
    # Field names come from the API contract, and a few plausible ones
    # (`display`, `hash`, `method`, `tap`, `then`, `format`...) are already
    # methods every Ruby object inherits. Left in place, `f.display "..."` would
    # call `Kernel#display` instead of emitting a field — silently, and only for
    # those names. Undefining everything outside this allowlist routes every
    # field name through `method_missing`. Introspection is kept so the object
    # stays debuggable.
    KEEP = %i[
      __send__ __id__ object_id class inspect to_s respond_to? nil?
      is_a? kind_of? instance_of? == != equal? !
      instance_variable_get instance_variable_set
    ].freeze

    instance_methods.each do |m|
      undef_method(m) unless KEEP.include?(m) || m.to_s.start_with?("__")
    end

    # Reached through `f`, so they must not go to `method_missing`.
    RESERVED = %i[set nest visible?].freeze

    def initialize(json, visible_attributes)
      @json = json
      @visible = visible_attributes.to_set
    end

    def visible?(key)
      @visible.include?(key)
    end

    # Explicit form of `f.some_field value`, for when the key is computed
    # (`f.set(:"#{key}_id", ...)`). The blank slate below undefines
    # `public_send`, so a computed key has to come through here.
    def set(key, *args, &block)
      # Checked before the visibility test on purpose: a malformed call must
      # fail for every user, not just the ones who can see the field.
      if args.size > 1 || (args.empty? && block.nil?) || (args.any? && block)
        raise ArgumentError, "#{key}: pass exactly one of a value or a block"
      end

      return unless visible?(key)

      @json.set!(key, block ? block.call : args.first)
    end

    # Emits a nested object or array. The block writes to `json` itself, so it
    # runs only when the key is visible.
    def nest(key)
      return unless visible?(key)

      @json.set!(key) { yield }
    end

    def method_missing(key, *args, &block)
      return super if RESERVED.include?(key) || key.to_s.end_with?("!", "?", "=")

      set(key, *args, &block)
    end

    def respond_to_missing?(key, include_private = false)
      return super if RESERVED.include?(key) || key.to_s.end_with?("!", "?", "=")

      true
    end

  end
end
