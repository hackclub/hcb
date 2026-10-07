# frozen_string_literal: true

module CardLocking
  # Pure computation of a charge's receipt deadline. No database, no clock.
  #
  # A deadline is `settled_at + RECEIPT_DUE_WINDOW` for an untrusted cardholder.
  # For a trusted cardholder it slides to `last_charge + RECEIPT_DUE_WINDOW`,
  # never below the base and never past `settled_at + RECEIPT_MAX_AGE`.
  #
  # When recomputation would move an existing deadline *earlier*, it may not drop
  # below `now + DEADLINE_SHORTENING_FLOOR`, so losing trust cannot make a pile of
  # receipts overdue in the same instant.
  class Deadline
    def initialize(settled_at:, trusted:, last_settled_charge_at:, current_due_at:, now:, resolved: false)
      @settled_at = settled_at
      @trusted = trusted
      @last_settled_charge_at = last_settled_charge_at
      @current_due_at = current_due_at
      @now = now
      @resolved = resolved
    end

    def compute
      # A first-ever deadline may not land already overdue. No-op for a normal
      # charge, whose settled_at + 7d is far past now + 72h; it only bites when a
      # charge is first materialized long after it settled, which would otherwise
      # lock a cardholder instantly with no pre-lock warning.
      #
      # Outstanding charges only. A resolved charge's deadline is history, read by
      # receipt_trusted? to decide whether its receipt arrived on time, and moving
      # it forward would recast a late upload as on-time. Not hypothetical:
      # BackfillCardLockingTimingTask materializes all history at Time.current, so
      # clamping there would inflate trust wholesale.
      return [target, @now + DEADLINE_SHORTENING_FLOOR].max if @current_due_at.nil? && !@resolved
      return target if @current_due_at.nil?
      return @current_due_at if @current_due_at <= @now # already overdue: frozen

      return target if target >= @current_due_at # lengthening is always allowed

      # Shortening: clamp between the 72h floor and the old value.
      [[target, @now + DEADLINE_SHORTENING_FLOOR].max, @current_due_at].min
    end

    private

    def target
      @target ||= begin
        base = @settled_at + RECEIPT_DUE_WINDOW
        if @trusted && @last_settled_charge_at
          slide = @last_settled_charge_at + RECEIPT_DUE_WINDOW
          [[slide, base].max, @settled_at + RECEIPT_MAX_AGE].min
        else
          base
        end
      end
    end

  end
end
