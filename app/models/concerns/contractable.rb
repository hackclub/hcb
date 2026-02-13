# frozen_string_literal: true

module Contractable
  extend ActiveSupport::Concern

  included do
    has_many :contracts, as: :contractable, dependent: :destroy

    def on_contract_signed(contract)
      # This method is a callback that can be overwritten in specific classes
      nil
    end

    def on_contract_party_signed(party)
      # This method is a callback that can be overwritten in specific classes
      nil
    end

    def on_contract_voided(contract)
      # This method is a callback that can be overwritten in specific classes
      nil
    end

    def contract_notify_when_sent
      # This method can be overwritten in specific classes to disable sending emails to parties when the contract is sent
      true
    end

    def contract_redirect_path
      # This method can be overwritten in specific classes to set the path that contract-related routes should redirect to
      "/"
    end

    def contract_notify_hcb?
      # This method can be overwritten in specific classes to disable sending HCB's notification when all other parties have signed
      true
    end
  end
end
