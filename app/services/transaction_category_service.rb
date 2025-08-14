# frozen_string_literal: true

class TransactionCategoryService
  def initialize(model:)
    @model = model
  end

  def set!(name)
    unless name.present?
      clear!
      return
    end

    assign!(TransactionCategory.find_or_create_by!(name:))
  end

  private

  attr_reader(:model)

  def clear!
    case model
    when CanonicalTransaction
      model.canonical_transaction_category&.destroy!
    when CanonicalPendingTransaction
      model.canonical_pending_transaction_category&.destroy!
    else
      raise ArgumentError.new("unsupported model class: #{model.class.name}")
    end
  end

  def assign!(transaction_category)
    assignment =
      case model
      when CanonicalTransaction
        model.canonical_transaction_category || model.build_canonical_transaction_category
      when CanonicalPendingTransaction
        model.canonical_pending_transaction_category || model.build_canonical_pending_transaction_category
      else
        raise ArgumentError.new("unsupported model class: #{model.class.name}")
      end

    assignment.update!(transaction_category:)
  end

end
