# frozen_string_literal: true

module Contractable
  extend ActiveSupport::Concern

  included do
    has_many :contracts, as: :contractable, dependent: :destroy

    def on_contract_signed
      # This method is a callback that can be overwritten in specific classes
      nil
    end

    def on_contract_voided
      # This method is a callback that can be overwritten in specific classes
      nil
    end

    def contract_docuseal_template_id
      # This method should be overwritten in specific classes
      raise NotImplementedError, "The #{self.class.name} model includes Contractable, but hasn't implemented its own version of contract_docuseal_template_id."
    end
  end
end
