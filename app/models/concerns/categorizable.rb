# frozen_string_literal: true

module Categorizable
  extend ActiveSupport::Concern

  included do
    has_one :category_mapping, class_name: "TransactionCategoryMapping", as: :categorizable
    has_one :category, class_name: "TransactionCategory", through: :category_mapping
  end
end
