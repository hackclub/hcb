# frozen_string_literal: true

# Per-field read authorization, declared in each record's Pundit policy next to
# the rest of its rules:
#
#   class CheckDepositPolicy < ApplicationPolicy
#     fields :front, :back, if: :view_image?
#   end
#
# While a controller renders a response, reading one of those fields checks the
# record's own policy against the viewer (the same `pundit_user` that
# `authorize` checks). That covers every record the view touches, however it
# got there, including records loaded through associations. Outside rendering
# (controller actions, services, jobs, mailers) fields read normally, so saving
# and business logic always see real values. Unsaved records are never guarded:
# their values came from the person filling in the form.
#
# Views never call policies. A template that only shows something when the
# viewer can see it asks the record (`check_deposit.readable?(:front)`), and API
# views wrap optional output in `FieldGuard.omit_hidden { ... }`, which leaves
# those keys out when the block reads a hidden field. Views that print whole
# records, like the admin record inspector, wrap that in `FieldGuard.redact`.
#
# Reading a hidden field anywhere else is a bug in the view. It raises
# FieldGuard::Violation in development and test. In production it is reported
# and the read returns FieldGuard::HIDDEN, so the page still renders. Set
# `config.x.field_guard.on_violation` to `:raise` or `:report` to override.
module FieldGuard
  class Violation < StandardError
    def initialize(record, field)
      super("#{record.class.name}##{field} is not readable by the viewer of this response")
    end

  end

  # What a hidden field reads as in production.
  class Hidden
    def to_s = "Hidden"
    def inspect = "#<FieldGuard::Hidden>"
    def blank? = true
    def present? = false
    def as_json(*) = nil

  end

  HIDDEN = Hidden.new.freeze

  # Policies decide who sees what, so they read real values even when a view
  # calls one mid-render (to decide whether to show a button, for example).
  class UnguardedPolicy < SimpleDelegator
    def method_missing(name, *args, **kwargs, &block)
      FieldGuard.unguarded { super(name, *args, **kwargs, &block) }
    end

    def respond_to_missing?(name, include_private = false)
      super
    end

  end

  class << self
    # Turns field checks on for `viewer` while the block runs.
    def enforce(viewer)
      previous = state
      self.state = { viewer:, results: {}.compare_by_identity, omitting: 0, redacting: 0 }
      yield
    ensure
      self.state = previous
    end

    # Whether the viewer may read `field` on `record`. Always true outside
    # `enforce`, for unsaved records, and for fields no policy guards.
    def readable?(record, field)
      current = state
      return true if current.nil? || !guarded?(record, field) || record.new_record?

      results = current[:results][record] ||= {}
      return results[field] if results.key?(field)

      # Policies read the record's real values, so their own reads aren't checked.
      results[field] = unguarded { Pundit.policy!(current[:viewer], record).readable_field?(field) }
    end

    # Runs the block with field checks off.
    def unguarded
      previous = state
      self.state = nil
      yield
    ensure
      self.state = previous
    end

    # Called by a guarded reader when the viewer can't read the field.
    def violation(record, field)
      current = state
      error = Violation.new(record, field)
      error.set_backtrace(caller(1))
      raise error if current[:omitting].positive?
      return HIDDEN if current[:redacting].positive?
      raise error if raise_violations?

      Rails.error.report(error, handled: true)
      HIDDEN
    end

    # Returns the block's result, or nil if the block reads a field the viewer
    # can't see.
    def omit_hidden
      within(:omitting) do
        yield
      rescue Violation
        nil
      end
    end

    # Fields the viewer can't see read as HIDDEN inside the block, without
    # raising or reporting. For views that print whole records, like the admin
    # record inspector.
    def redact(&)
      within(:redacting, &)
    end

    # Wraps each field's reader on `model` so it checks the viewer first.
    # Called by ApplicationPolicy.fields when a policy loads.
    def install(model, fields)
      new_fields = fields - model.guarded_fields.to_a
      model.guarded_fields = (model.guarded_fields | fields).freeze
      new_fields.each { |field| guard_reader(model, field) }
    end

    private

    def state
      ActiveSupport::IsolatedExecutionState[:field_guard]
    end

    def state=(value)
      ActiveSupport::IsolatedExecutionState[:field_guard] = value
    end

    def guarded?(record, field)
      record.class.respond_to?(:guarded_field?) && record.class.guarded_field?(field)
    end

    def raise_violations?
      mode = Rails.configuration.x.field_guard.on_violation
      mode.nil? ? !Rails.env.production? : mode.to_sym == :raise
    end

    def within(counter)
      current = state
      return yield if current.nil?

      current[counter] += 1
      begin
        yield
      ensure
        current[counter] -= 1
      end
    end

    # The wrapper replaces the reader on the model itself rather than in a
    # prepended module, because RSpec's `allow_any_instance_of` can't stub
    # methods that live in a prepended module.
    def guard_reader(model, field)
      if model.method_defined?(field, false) || model.private_method_defined?(field, false)
        # Defined on the model itself (a `def`, `delegate`, `alias`, memo_wise).
        original = model.instance_method(field)
        private_reader = model.private_method_defined?(field, false)
        model.define_method(field) do |*args, **kwargs, &block|
          if FieldGuard.readable?(self, field)
            original.bind_call(self, *args, **kwargs, &block)
          else
            FieldGuard.violation(self, field)
          end
        end
        model.send(:private, field) if private_reader
      else
        # Defined in a module Rails generates for attributes, associations and
        # attachments, so the wrapper calls up to it.
        model.define_method(field) do |*args, **kwargs, &block|
          if FieldGuard.readable?(self, field)
            super(*args, **kwargs, &block)
          else
            FieldGuard.violation(self, field)
          end
        end
      end
    end

  end

end
