# frozen_string_literal: true

# == Schema Information
#
# Table name: canonical_transaction_categories
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
#  idx_on_canonical_transaction_id_83a8a6bf99  (canonical_transaction_id) UNIQUE
#  idx_on_transaction_category_id_5691e8a7b0   (transaction_category_id)
#
# Foreign Keys
#
#  fk_rails_...  (canonical_transaction_id => canonical_transactions.id)
#  fk_rails_...  (transaction_category_id => transaction_categories.id)
#
class CanonicalTransactionCategory < ApplicationRecord
  belongs_to(:transaction_category)
  belongs_to(:canonical_transaction)

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
