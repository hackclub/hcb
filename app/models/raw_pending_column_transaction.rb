# frozen_string_literal: true

# == Schema Information
#
# Table name: raw_pending_column_transactions
#
#  id                 :bigint           not null, primary key
#  amount_cents       :integer          not null
#  column_event_type  :integer          not null
#  column_transaction :jsonb            not null
#  date_posted        :date             not null
#  description        :text             not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  column_id          :string           not null
#
# Indexes
#
#  index_raw_pending_column_transactions_on_column_id  (column_id) UNIQUE
#
class RawPendingColumnTransaction < ApplicationRecord
  has_one :canonical_pending_transaction

  after_create :create_canonical_pending_transaction, if: -> { canonical_pending_transaction.nil? }

  enum :column_event_type, {
    "swift.incoming_transfer.completed": 0,
    "wire.incoming_transfer.completed": 1,
    "ach.incoming_transfer.settled": 2
  }

  def create_canonical_pending_transaction
    column_account_number = Column::AccountNumber.find_by(column_id: column_transaction["account_number_id"])
    return unless column_account_number

    create_canonical_pending_transaction!(
      amount_cents:,
      memo:,
      date: date_posted,
      event: column_account_number.event,
      fronted: true
    )
  end

  def memo
    if column_id.start_with? "acht"
      return "#{column_transaction.fetch("company_name")} #{column_transaction["company_entry_description"]}"
    elsif column_id.start_with?("wire") || column_id.start_with?("swft_")
      return column_transaction.fetch("originator_name")
    end
  end

  before_validation on: :create do
    self.description = memo
  end

end
