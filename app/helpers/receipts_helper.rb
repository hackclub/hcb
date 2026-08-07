# frozen_string_literal: true

module ReceiptsHelper
  # Buckets a charge that is missing a receipt by when its receipt is due.
  #
  # Everything already past its deadline collapses into a single `:overdue`
  # bucket — the exact day it went overdue isn't actionable, it's all equally
  # urgent. Everything else buckets by the calendar day it is due on. Charges
  # with no deadline at all — cardholders who aren't under card-locking
  # enforcement yet, so `receipt_due_at` was never materialized — get their own
  # trailing `:none` bucket rather than a made-up date.
  def receipt_due_group(hcb_code, now: Time.current)
    due_at = hcb_code.receipt_due_at

    return :none if due_at.nil?
    return :overdue if due_at <= now

    due_at.to_date
  end

  def receipt_due_group_label(group, now: Time.current)
    case group
    when :overdue then "Overdue"
    when :none then "No deadline"
    else
      case (group - now.to_date).to_i
      when 0 then "Due today"
      when 1 then "Due tomorrow"
      when 2..6 then "Due #{group.strftime("%A")}"
      else "Due #{group.strftime("%b %-d")}"
      end
    end
  end

  def receipt_due_group_urgency(group, now: Time.current)
    case group
    when :overdue then :overdue
    when :none then :none
    else (group - now.to_date).to_i <= 1 ? :soon : :later
    end
  end

  # How a group's header renders. Kept here rather than in the view so urgency is
  # only derived once and the icon/colour pairing lives next to the buckets.
  def receipt_due_group_style(group, now: Time.current)
    case receipt_due_group_urgency(group, now:)
    when :overdue then { icon: "important-fill", icon_class: "error", badge_class: "bg-error" }
    when :soon then { icon: "clock-fill", icon_class: "muted", badge_class: "bg-warning" }
    else { icon: "clock", icon_class: "muted", badge_class: "bg-muted" }
    end
  end

end
