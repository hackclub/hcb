# frozen_string_literal: true

module HasLedgerItem
  extend ActiveSupport::Concern

  included do
    has_one :ledger_item, class_name: "Ledger::Item", as: :linked_object
  end
end
