# frozen_string_literal: true

module HasSubledger
  extend ActiveSupport::Concern

  included do
    scope :on_main_ledger, -> { where(subledger_id: nil) }
  end
end
