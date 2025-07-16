# frozen_string_literal: true

# == Schema Information
#
# Table name: raw_column_transactions
#
#  id                 :bigint           not null, primary key
#  amount_cents       :integer
#  column_transaction :jsonb
#  date_posted        :date
#  description        :text
#  transaction_index  :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  column_report_id   :string
#
class RawColumnTransaction < ApplicationRecord
  has_one :canonical_transaction, as: :transaction_source

  after_create :canonize, if: -> { canonical_transaction.nil? }

  def canonize
    create_canonical_transaction!(
      amount_cents:,
      memo:,
      date: date_posted,
    )
  end

  def memo
    transaction_id = column_transaction["transaction_id"]
    if transaction_id.start_with? "acht" # TODO: use `transaction_type` instead
      ach_transfer = ColumnService.ach_transfer(transaction_id)

      return "#{ach_transfer["company_name"]} #{ach_transfer["company_entry_description"]}"
    elsif transaction_id.start_with? "book"
      book_transfer = ColumnService.get "/transfers/book/#{transaction_id}"

      return book_transfer["description"]
    elsif transaction_id.start_with? "wire"
      wire = ColumnService.get "/transfers/wire/#{transaction_id}"

      return wire["originator_name"]
    elsif transaction_id.start_with? "swft_"
      wire = ColumnService.get "/transfers/international-wire/#{transaction_id}"

      return wire["originator_name"]
    elsif transaction_id.start_with? "ipay_"
      return "INTEREST"
    elsif transaction_id.start_with? "rttr_"
      realtime = ColumnService.get "/transfers/realtime/#{transaction_id}"

      return realtime["description"]
    end
    raise
  rescue
    if amount_cents.positive?
      "DEPOSIT"
    else
      "DEBIT"
    end
  end

  def transaction_type
    column_transaction["transaction_type"]
  end

  def transaction_id
    column_transaction["transaction_id"]
  end

  def remote_object
    transaction_id = column_transaction["transaction_id"]
    if transaction_id.start_with? "acht"
      ColumnService.ach_transfer(transaction_id)
    elsif transaction_id.start_with? "book"
      ColumnService.get "/transfers/book/#{transaction_id}"
    elsif transaction_id.start_with? "wire"
      ColumnService.get "/transfers/wire/#{transaction_id}"
    elsif transaction_id.start_with? "swft_"
      ColumnService.get "/transfers/international-wire/#{transaction_id}"
    elsif transaction_id.start_with? "rttr_"
      ColumnService.get "/transfers/realtime/#{transaction_id}"
    else
      nil
    end
  rescue
    nil
  end

end
