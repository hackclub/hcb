# frozen_string_literal: true

# == Schema Information
#
# Table name: raw_pending_bank_fee_transactions
#
#  id                      :bigint           not null, primary key
#  amount_cents            :integer
#  date_posted             :date
#  state                   :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  bank_fee_transaction_id :string
#
class RawPendingBankFeeTransaction < ApplicationRecord
  monetize :amount_cents

  def date
    date_posted
  end

  def memo
    "Fiscal sponsorship"
  end

  def likely_event_id
    @likely_event_id ||= bank_fee.event.id
  end

  def bank_fee
    @bank_fee ||= ::BankFee.find_by(id: bank_fee_transaction_id)
  end

end
