# frozen_string_literal: true

class TransactionCategoryService
  def initialize(model:)
    @model = model
  end

  def set!(name:, assignment_strategy: nil)
    unless name.present?
      model.category_mapping&.destroy!
      return
    end

    category = TransactionCategory.find_or_create_by!(name:)
    mapping = model.category_mapping || model.build_category_mapping
    mapping.category = category
    mapping.assignment_strategy = assignment_strategy if assignment_strategy.present?
    mapping.save!
  end

  private

  attr_reader(:model)

end
