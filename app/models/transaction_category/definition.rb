# frozen_string_literal: true

class TransactionCategory
  Definition = Struct.new(:name, :type, :group, keyword_init: true) do
    def self.load_all
      path = Rails.root.join("db/data/transaction_categories.json")
      JSON.parse(File.read(path)).to_h do |name, attributes|
        [
          name.freeze,
          Definition.new(
            name:,
            type: attributes.fetch("type"),
            group: attributes.fetch("group")
          ).freeze
        ]
      end.freeze
    end
  end

  Definition::ALL = Definition.load_all

end
