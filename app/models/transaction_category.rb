# frozen_string_literal: true

# == Schema Information
#
# Table name: transaction_categories
#
#  id         :bigint           not null, primary key
#  slug       :citext           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_transaction_categories_on_slug  (slug) UNIQUE
#
class TransactionCategory < ApplicationRecord
  has_many(:transaction_category_mappings, inverse_of: :category)
  has_many(
    :canonical_transactions,
    through: :transaction_category_mappings,
    source: :categorizable,
    source_type: "CanonicalTransaction"
  )
  has_many(
    :canonical_pending_transactions,
    through: :transaction_category_mappings,
    source: :categorizable,
    source_type: "CanonicalPendingTransaction"
  )

  validates(
    :slug,
    presence: true,
    uniqueness: { case_sensitive: false },
    inclusion: { in: TransactionCategory::Definition::ALL.keys }
  )

  delegate :label, to: :definition

  def definition
    TransactionCategory::Definition::ALL.fetch(slug)
  end

end
