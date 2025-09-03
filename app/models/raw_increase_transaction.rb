# frozen_string_literal: true

# == Schema Information
#
# Table name: raw_increase_transactions
#
#  id                      :bigint           not null, primary key
#  amount_cents            :integer
#  date_posted             :date
#  description             :text
#  increase_route_type     :text
#  increase_transaction    :jsonb
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  increase_account_id     :text
#  increase_route_id       :text
#  increase_transaction_id :text
#
# Indexes
#
#  index_raw_increase_transactions_on_increase_transaction_id  (increase_transaction_id) UNIQUE
#
class RawIncreaseTransaction < ApplicationRecord
  has_many :hashed_transactions
  has_one :canonical_transaction, as: :transaction_source

  belongs_to :increase_account_number,
             foreign_key: "increase_route_id",
             primary_key: "increase_account_number_id",
             optional: true

  has_one :event, through: :increase_account_number

  def memo
    if category == "inbound_ach_transfer"
      originator_company_name = increase_transaction.dig("source", "inbound_ach_transfer", "originator_company_name")
      originator_company_entry_description = increase_transaction.dig("source", "inbound_ach_transfer", "originator_company_entry_description")

      "#{originator_company_name} #{originator_company_entry_description}"
    else
      description
    end
  end

  def category
    increase_transaction.dig("source", "category")
  end

  def unique_bank_identifier
    "INCREASE-#{increase_account_id.upcase}"
  end

end
