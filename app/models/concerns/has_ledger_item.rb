# frozen_string_literal: true

module HasLedgerItem
  extend ActiveSupport::Concern

  included do
    has_one :ledger_item, as: :linked_object

    after_create :create_ledger_item

    def create_ledger_item
      Ledger::Item.find_or_create_by(linked_object: self)
    end
  end
end
