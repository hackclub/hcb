# frozen_string_literal: true

module CardLocking
  # Pure computation of a charge's receipt deadline. No database, no clock.
  #
  # A deadline is `settled_at + RECEIPT_DUE_WINDOW` for an untrusted cardholder.
  # For a trusted cardholder it slides to `last_charge + RECEIPT_DUE_WINDOW`,
  # never below the base and never past `settled_at + RECEIPT_MAX_AGE`.
  #
  # An outstanding deadline that is still in the future never moves earlier. A
  # deadline can sit past its computed target for reasons this class can't see:
  # the countdown restarted when the charge's last receipt was deleted
  # (ChargeBehavior#restart_card_locking_countdown!), rollout grace, or a trusted
  # slide the cardholder has since lost. Recomputing would claw each of those
  # back, so a recompute may only lengthen.
  class Deadline
    def initialize(settled_at:, trusted:, last_settled_charge_at:, current_due_at:, now:, resolved: false, cards_locked: false)
      @settled_at = settled_at
      @trusted = trusted
      @last_settled_charge_at = last_settled_charge_at
      @current_due_at = current_due_at
      @now = now
      @resolved = resolved
      @cards_locked = cards_locked
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
      #
      # Unlocked cardholders only. The floor exists to warn before a lock, and a
      # cardholder whose cards are already locked has had that warning and the
      # lock. Flooring their charges would instead clear every overdue deadline
      # for 72 hours, so the next sweep would unlock them, mail them that their
      # cards work again, and lock them back three days later. That is exactly
      # what happens when deadlines are first materialized onto ledger items
      # that have none yet, so this is what lets the sweep fill them from
      # scratch without a notification going out.
      return [target, @now + FIRST_DEADLINE_FLOOR].max if @current_due_at.nil? && !@resolved && !@cards_locked
      return target if @current_due_at.nil?
      return @current_due_at if @current_due_at <= @now # already overdue: frozen

      # Lengthening is always allowed; shortening never is.
      [target, @current_due_at].max
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
