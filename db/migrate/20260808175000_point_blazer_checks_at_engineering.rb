# frozen_string_literal: true

# Existing checks still notify hcb@, which lands in Intercom.
# Migrate all checks that use operations email to use engr email.

class PointBlazerChecksAtEngineering < ActiveRecord::Migration[8.1]
  OPERATIONS_EMAIL = "hcb@hackclub.com"
  ENGINEERING_EMAIL = "hcb-engr@hackclub.com"

  def up
    Blazer::Check.where("emails ILIKE ?", "%#{OPERATIONS_EMAIL}%").find_each do |check|
      recipients = check.emails.to_s.split(",").map { |email| email.strip.downcase }
      rewritten = recipients.map { |email| email == OPERATIONS_EMAIL ? ENGINEERING_EMAIL : email }.uniq
      next if rewritten == recipients

      check.update_columns(emails: rewritten.join(", "))
    end
  end

  def down
  end

end
