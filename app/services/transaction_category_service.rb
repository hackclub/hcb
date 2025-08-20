# frozen_string_literal: true

class TransactionCategoryService
  def initialize(model:)
    unless model.is_a?(Categorizable)
      raise ArgumentError, "unsupported model type: #{model.class.name}"
    end

    @model = model
  end

  def set!(slug:, assignment_strategy: nil)
    unless slug.present?
      model.category_mapping&.destroy!
      return
    end

    category = TransactionCategory.find_or_create_by!(slug:)
    mapping = model.category_mapping || model.build_category_mapping
    mapping.category = category
    mapping.assignment_strategy = assignment_strategy if assignment_strategy.present?
    mapping.save!
  end

  private

  attr_reader(:model)

end
