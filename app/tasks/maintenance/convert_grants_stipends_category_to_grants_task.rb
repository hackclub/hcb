# frozen_string_literal: true

module Maintenance
  class ConvertGrantsStipendsCategoryToGrantsTask < MaintenanceTasks::Task
    def collection
      TransactionCategoryMapping
        .joins(:category)
        .where(transaction_categories: { slug: "grants-stipends" })
    end

    def process(mapping)
      mapping.update!(category: grants_category)
    end

    private

    def grants_category
      @grants_category ||= TransactionCategory.find_or_create_by!(slug: "grants")
    end

  end
end
