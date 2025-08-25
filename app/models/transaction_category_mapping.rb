# frozen_string_literal: true

# == Schema Information
#
# Table name: transaction_category_mappings
#
#  id                      :bigint           not null, primary key
#  assignment_strategy     :text             not null
#  categorizable_type      :text             not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  categorizable_id        :bigint           not null
#  transaction_category_id :bigint           not null
#
# Indexes
#
#  idx_on_categorizable_type_categorizable_id_f3e1245d19           (categorizable_type,categorizable_id) UNIQUE
#  index_transaction_category_mappings_on_transaction_category_id  (transaction_category_id)
#
# Foreign Keys
#
#  fk_rails_...  (transaction_category_id => transaction_categories.id)
#
class TransactionCategoryMapping < ApplicationRecord
  belongs_to(
    :category,
    class_name: "TransactionCategory",
    foreign_key: :transaction_category_id,
    inverse_of: :transaction_category_mappings
  )
  belongs_to(:categorizable, polymorphic: true)

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
