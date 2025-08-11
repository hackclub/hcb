# frozen_string_literal: true

# == Schema Information
#
# Table name: canonical_pending_transaction_category_mappings
#
#  id                               :bigint           not null, primary key
#  assignment_strategy              :text             not null
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#  canonical_pending_transaction_id :bigint           not null
#  transaction_category_id          :bigint           not null
#
# Indexes
#
#  idx_on_canonical_pending_transaction_id_8616db5cc4  (canonical_pending_transaction_id) UNIQUE
#  idx_on_transaction_category_id_a960252169           (transaction_category_id)
#
# Foreign Keys
#
#  fk_rails_...  (canonical_pending_transaction_id => canonical_pending_transactions.id)
#  fk_rails_...  (transaction_category_id => transaction_categories.id)
#
class CanonicalPendingTransactionCategoryMapping < ApplicationRecord
  belongs_to(:category, class_name: "TransactionCategory", foreign_key: :transaction_category_id)
  belongs_to(:canonical_pending_transaction, inverse_of: :category_mapping)

  enum(
    :assignment_strategy,
    {
      manual: "manual",
      automatic: "automatic",
    },
    default: :automatic,
    validate: true
  )

end
