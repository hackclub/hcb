# frozen_string_literal: true

class TransactionCategory
  Definition = Struct.new(:slug, :label, :type, :group, keyword_init: true) do
    def self.load_all
      path = Rails.root.join("db/data/transaction_categories.json")
      JSON.parse(File.read(path)).to_h do |slug, attributes|
        [
          slug.freeze,
          Definition.new(
            slug:,
            label: attributes.fetch("label"),
            type: attributes.fetch("type"),
            group: attributes.fetch("group")
          ).freeze
        ]
      end.freeze
    end
  end

  Definition::ALL = Definition.load_all

end
