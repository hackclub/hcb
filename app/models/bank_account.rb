# frozen_string_literal: true

# == Schema Information
#
# Table name: bank_accounts
#
#  id                            :bigint           not null, primary key
#  failed_at                     :datetime
#  failure_count                 :integer          default(0)
#  is_positive_pay               :boolean
#  name                          :text
#  plaid_access_token_ciphertext :text
#  should_sync                   :boolean          default(TRUE)
#  should_sync_v2                :boolean          default(FALSE)
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  plaid_account_id              :text
#  plaid_item_id                 :text
#
class BankAccount < ApplicationRecord
  has_paper_trail skip: [:plaid_access_token] # ciphertext columns will still be tracked
  has_encrypted :plaid_access_token

  has_many :transact_so_ns
  has_many :raw_plaid_transactions, primary_key: :plaid_account_id, foreign_key: :plaid_account_id
  has_many :canonical_transactions, through: :raw_plaid_transactions

  scope :syncing, -> { where(should_sync: true) }
  scope :syncing_v2, -> { where(should_sync_v2: true) }
  scope :failing, -> { where("failed_at is not null") }

  def balance
    canonical_transactions.sum(:amount_cents)
  end

  def failing?
    failed_at.present?
  end

  def admin_status_color
    if should_sync_v2?
      if failing?
        "admin-bg-red"
      else
        "admin-bg-transit"
      end
    end
  end

end
