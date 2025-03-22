# frozen_string_literal: true

# == Schema Information
#
# Table name: raw_intrafi_transactions
#
#  id           :bigint           not null, primary key
#  amount_cents :integer          not null
#  date_posted  :date             not null
#  memo         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class RawIntrafiTransaction < ApplicationRecord
  has_one :canonical_transaction, as: :transaction_source

  after_create :canonize, if: -> { canonical_transaction.nil? }

  def canonize
    create_canonical_transaction!(
      amount_cents:,
      memo:,
      date: date_posted,
    )
  end

end
