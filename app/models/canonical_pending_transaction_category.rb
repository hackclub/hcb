# frozen_string_literal: true

# == Schema Information
#
# Table name: canonical_pending_transaction_categories
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
#  idx_on_canonical_pending_transaction_id_510f53a010  (canonical_pending_transaction_id) UNIQUE
#  idx_on_transaction_category_id_b389fdeaab           (transaction_category_id)
#
# Foreign Keys
#
#  fk_rails_...  (canonical_pending_transaction_id => canonical_pending_transactions.id)
#  fk_rails_...  (transaction_category_id => transaction_categories.id)
#
class CanonicalPendingTransactionCategory < ApplicationRecord
  belongs_to(:transaction_category)
  belongs_to(:canonical_pending_transaction)

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
