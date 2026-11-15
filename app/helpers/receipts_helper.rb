# frozen_string_literal: true

module ReceiptsHelper
  # Buckets a charge that is missing a receipt by when its receipt is due:
  # a single :overdue bucket, then one bucket per calendar day, then :pending
  # for charges that haven't settled yet, then :none for charges that never had
  # a deadline (cardholders outside enforcement).
  def receipt_due_group(hcb_code, now: Time.current)
    due_at = hcb_code.receipt_due_at

    # A pending charge has no deadline because its clock only starts once it
    # settles. That makes it the newest thing on the page, not the oldest, so it
    # gets its own bucket rather than sitting with the undated long tail.
    return hcb_code.canonical_transactions.empty? ? :pending : :none if due_at.nil?
    return :overdue if due_at <= now

    due_at.to_date
  end

  def receipt_due_group_label(group, now: Time.current)
    case group
    when :overdue then "Overdue"
    when :pending then "Pending transactions"
    when :none then "Older receipts"
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
    when :pending then :pending
    when :none then :none
    else (group - now.to_date).to_i <= 1 ? :soon : :later
    end
  end

  # Icon and badge classes for a group's header.
  def receipt_due_group_style(group, now: Time.current)
    case receipt_due_group_urgency(group, now:)
    when :overdue then { icon: "important-fill", icon_class: "error", badge_class: "bg-error" }
    when :soon then { icon: "clock-fill", icon_class: "muted", badge_class: "bg-warning" }
    else { icon: "clock", icon_class: "muted", badge_class: "bg-muted" }
    end
  end

end
