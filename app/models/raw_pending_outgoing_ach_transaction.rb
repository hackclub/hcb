# frozen_string_literal: true

# == Schema Information
#
# Table name: raw_pending_outgoing_ach_transactions
#
#  id                 :bigint           not null, primary key
#  amount_cents       :integer
#  date_posted        :date
#  state              :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  ach_transaction_id :text
#
class RawPendingOutgoingAchTransaction < ApplicationRecord
  monetize :amount_cents
  belongs_to :ach_transfer, foreign_key: :ach_transaction_id
  has_one :canonical_pending_transaction

  def date
    date_posted
  end

  def memo
    "ACH to #{raw_name}".strip
  end

  def likely_event_id
    @likely_event_id ||= ach_transfer.event.id
  end

  private

  def raw_name
    ach_transfer.recipient_name
  end

end
