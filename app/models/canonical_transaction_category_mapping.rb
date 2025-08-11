# frozen_string_literal: true

# == Schema Information
#
# Table name: canonical_transaction_category_mappings
#
#  id                       :bigint           not null, primary key
#  assignment_strategy      :text             not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  canonical_transaction_id :bigint           not null
#  transaction_category_id  :bigint           not null
#
# Indexes
#
#  idx_on_canonical_transaction_id_6bbda33213  (canonical_transaction_id) UNIQUE
#  idx_on_transaction_category_id_37a4eb69bc   (transaction_category_id)
#
# Foreign Keys
#
#  fk_rails_...  (canonical_transaction_id => canonical_transactions.id)
#  fk_rails_...  (transaction_category_id => transaction_categories.id)
#
class CanonicalTransactionCategoryMapping < ApplicationRecord
  belongs_to(:category, class_name: "TransactionCategory", foreign_key: :transaction_category_id)
  belongs_to(:canonical_transaction, inverse_of: :category_mapping)

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
