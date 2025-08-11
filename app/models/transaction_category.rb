# frozen_string_literal: true

# == Schema Information
#
# Table name: transaction_categories
#
#  id         :bigint           not null, primary key
#  name       :citext           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_transaction_categories_on_name  (name) UNIQUE
#
class TransactionCategory < ApplicationRecord
  has_many(:canonical_pending_transaction_category_mappings, inverse_of: :category)
  has_many(:canonical_pending_transactions, through: :canonical_pending_transaction_category_mappings)

  has_many(:canonical_transaction_category_mappings, inverse_of: :category)
  has_many(:canonical_transactions, through: :canonical_transaction_category_mappings)

  validates(:name, presence: true, uniqueness: { case_sensitive: false })

end
