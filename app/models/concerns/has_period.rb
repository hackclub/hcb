# frozen_string_literal: true

module HasPeriod
  extend ActiveSupport::Concern

  # Renders the period like "Jan 1 – Jun 30, 2026", collapsing within a single
  # month ("Apr 1–28, 2026") or spanning years ("Dec 1, 2025 – Feb 28, 2026") when needed.
  def period_label
    return if start_date.nil?
    return start_date.strftime("%b %-d, %Y") if end_date.nil? || start_date == end_date

    if start_date.year != end_date.year
      "#{start_date.strftime("%b %-d, %Y")} – #{end_date.strftime("%b %-d, %Y")}"
    elsif start_date.month != end_date.month
      "#{start_date.strftime("%b %-d")} – #{end_date.strftime("%b %-d, %Y")}"
    else
      "#{start_date.strftime("%b %-d")}–#{end_date.strftime("%-d, %Y")}"
    end
  end
end
