# frozen_string_literal: true

class TransactionCategory
  Definition = Struct.new(
    :slug,
    :label,
    :stripe_merchant_categories,
    :hq_only,
    keyword_init: true
  ) do
    def self.load_all
      path = Rails.root.join("db/data/transaction_categories.json")
      JSON.parse(File.read(path)).to_h do |slug, attributes|
        [
          slug.freeze,
          Definition.new(
            slug:,
            label: attributes.fetch("label"),
            stripe_merchant_categories: attributes.fetch("stripe_merchant_categories", []),
            hq_only: attributes.fetch("hq_only", false),
          ).freeze
        ]
      end.freeze
    end

    alias_method(:hq_only?, :hq_only)
  end

  Definition::ALL = Definition.load_all

  Definition::BY_STRIPE_MERCHANT_CATEGORY =
    Definition::ALL.each_with_object({}) do |(_slug, definition), hash|
      definition.stripe_merchant_categories.each do |stripe_merchant_category|
        hash[stripe_merchant_category] = definition
      end
    end.freeze

end
