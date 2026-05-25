# frozen_string_literal: true

module Contractable
  extend ActiveSupport::Concern

  included do
    has_many :contracts, as: :contractable, dependent: :destroy

    # We need to void associated contracts before contractable is deleted so that callbacks and validations can run
    before_destroy do
      contracts.where(aasm_state: [:pending, :sent]).find_each(&:mark_voided!)
    end

    def send_contract(cosigner_email: nil, include_videos: false, reissue_signee_message: nil, reissue_cosigner_message: nil)
      # This method should be overwritten in specific classes
      raise NotImplementedError, "The #{self.class.name} model includes Contractable, but hasn't implemented it's own version of send_contract."
    end

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
