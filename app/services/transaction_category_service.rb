# frozen_string_literal: true

class TransactionCategoryService
  prepend MemoWise

  def initialize(model:)
    unless model.is_a?(Categorizable)
      raise ArgumentError, "unsupported model type: #{model.class.name}"
    end

    @model = model
  end

  def set!(slug:, assignment_strategy: "automatic")
    unless TransactionCategoryMapping.assignment_strategies.key?(assignment_strategy)
      raise(ArgumentError, "invalid assignment strategy: #{assignment_strategy.inspect}")
    end

    # If this is an automatic assignment and there's an existing manual mapping,
    # do not proceed further
    return if assignment_strategy == "automatic" && model.category_mapping&.manual?

    unless slug.present?
      model.category_mapping&.destroy!
      return
    end

    category = TransactionCategory.find_or_create_by!(slug:)
    mapping = model.category_mapping || model.build_category_mapping
    mapping.category = category
    mapping.assignment_strategy = assignment_strategy
    mapping.save!
  end

  def sync_from_stripe!
    # If there's already a category assigned, don't reassign it
    return if @model.category.present?

    # Bail if the model isn't a stripe transaction or for some reason we can't
    # find the category
    return unless stripe_merchant_category.present?

    definition = TransactionCategory::Definition::BY_STRIPE_MERCHANT_CATEGORY[stripe_merchant_category]

    # We don't have mappings for every stripe category
    return unless definition

    category = TransactionCategory.find_or_create_by!(slug: definition.slug)
    model.create_category_mapping!(category:, assignment_strategy: "automatic")
  end

  # A refund (or a later capture) joins a card charge after the charge's
  # pending transaction has settled, so CanonicalPendingTransactionService::Settle
  # never runs for it and it settles without a category. Copy the charge's
  # category instead: the one on its earlier settled transaction, which a user
  # may have changed since it settled, or failing that the one on its pending
  # transaction.
  def sync_from_card_charge!
    return if model.category.present?

    mapping = card_charge_category_mapping
    return unless mapping

    set!(slug: mapping.category.slug, assignment_strategy: mapping.assignment_strategy)
  end

  private

  attr_reader(:model)

  def card_charge_category_mapping
    return unless model.is_a?(CanonicalTransaction)

    raw_stripe_transaction = model.raw_stripe_transaction
    card_charge = raw_stripe_transaction&.card_charge
    return unless card_charge

    settled_mapping = card_charge.raw_stripe_transactions
                                 .where.not(id: raw_stripe_transaction.id)
                                 .order(:id)
                                 .filter_map { |sibling| sibling.canonical_transaction&.category_mapping }
                                 .first

    settled_mapping || card_charge.raw_pending_stripe_transaction&.canonical_pending_transaction&.category_mapping
  end

  def stripe_merchant_category
    case model
    when CanonicalPendingTransaction
      model.raw_pending_stripe_transaction&.merchant_category
    when CanonicalTransaction
      model.raw_stripe_transaction&.merchant_category
    else
      raise ArgumentError, "unsupported model type: #{@model.class.name}"
    end
  end

  memo_wise(:stripe_merchant_category)

end
