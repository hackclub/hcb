# frozen_string_literal: true

# == Schema Information
#
# Table name: hashed_transactions
#
#  id                                 :bigint           not null, primary key
#  date                               :date
#  primary_hash                       :text
#  primary_hash_input                 :text
#  secondary_hash                     :text
#  unique_bank_identifier             :text
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  duplicate_of_hashed_transaction_id :bigint
#  raw_csv_transaction_id             :bigint
#  raw_emburse_transaction_id         :bigint
#  raw_increase_transaction_id        :bigint
#  raw_plaid_transaction_id           :bigint
#  raw_stripe_transaction_id          :bigint
#
# Indexes
#
#  idx_on_duplicate_of_hashed_transaction_id_6a29e8a078      (duplicate_of_hashed_transaction_id)
#  index_hashed_transactions_on_raw_csv_transaction_id       (raw_csv_transaction_id)
#  index_hashed_transactions_on_raw_increase_transaction_id  (raw_increase_transaction_id)
#  index_hashed_transactions_on_raw_plaid_transaction_id     (raw_plaid_transaction_id)
#  index_hashed_transactions_on_raw_stripe_transaction_id    (raw_stripe_transaction_id)
#
# Foreign Keys
#
#  fk_rails_...  (raw_plaid_transaction_id => raw_plaid_transactions.id)
#
class HashedTransaction < ApplicationRecord
  monetize :amount_cents

  belongs_to :raw_csv_transaction, optional: true
  belongs_to :raw_plaid_transaction, optional: true
  belongs_to :raw_emburse_transaction, optional: true
  belongs_to :raw_stripe_transaction, optional: true
  belongs_to :raw_increase_transaction, optional: true

  has_one :canonical_hashed_mapping
  has_one :canonical_transaction, through: :canonical_hashed_mapping

  belongs_to :duplicate_of_hashed_transaction, class_name: "HashedTransaction", optional: true
  has_many   :duplicate_hashed_transactions, class_name: "HashedTransaction", foreign_key: "duplicate_of_hashed_transaction_id"

  scope :marked_duplicate, -> { where.not(hashed_transaction_id: nil) }
  scope :uncanonized, -> { left_joins(:canonical_hashed_mapping).where(canonical_hashed_mappings: { id: nil }) }
  scope :possible_duplicates, -> { where(primary_hash: HashedTransaction.select(:primary_hash).group(:primary_hash).having("count(primary_hash) > 1").pluck(:primary_hash)) }

  def date
    self[:date] || determine_store_and_return_date
  end

  def memo
    raw_plaid_transaction.try(:memo) ||
      raw_emburse_transaction.try(:memo) ||
      raw_stripe_transaction.try(:memo) ||
      raw_csv_transaction.try(:memo) ||
      raw_increase_transaction.try(:memo)
  end

  def amount_cents
    raw_plaid_transaction.try(:amount_cents) ||
      raw_emburse_transaction.try(:amount_cents) ||
      raw_stripe_transaction.try(:amount_cents) ||
      raw_csv_transaction.try(:amount_cents) ||
      raw_increase_transaction.try(:amount_cents)
  end

  def unique_bank_identifier
    self[:unique_bank_identifier] || parse_store_and_return_unique_bank_identifier
  end

  private

  def determine_store_and_return_date
    d = raw_plaid_transaction.try(:date_posted) ||
        raw_emburse_transaction.try(:date_posted) ||
        raw_stripe_transaction.try(:date_posted) ||
        raw_csv_transaction.try(:date_posted) ||
        raw_increase_transaction.try(:date_posted)

    self.update_column(:date, d)

    d
  end

  def parse_store_and_return_unique_bank_identifier
    ubi = parse_unique_bank_identifier
    self.update_column(:unique_bank_identifier, ubi)

    ubi
  end

  def parse_unique_bank_identifier
    CSV.parse(primary_hash_input)[0][0]
  end

end
