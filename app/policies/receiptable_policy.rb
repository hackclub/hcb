# frozen_string_literal: true

# Receipt actions on any Receiptable. Who may attach receipts to a record is up
# to that record's own policy, through its `receiptable_upload?`.
class ReceiptablePolicy < ApplicationPolicy
  def upload?
    Pundit.policy(user, record).try(:receiptable_upload?)
  end

  def link?
    upload?
  end

  def link_modal?
    upload? || user&.auditor?
  end

  def mark_no_or_lost?
    upload?
  end

end
