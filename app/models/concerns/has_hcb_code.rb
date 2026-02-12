# frozen_string_literal: true

module HasHcbCode
  extend ActiveSupport::Concern

  class_methods do
    # Sets the HCB code type constant for this model.
    #
    # Usage:
    #   class Wire < ApplicationRecord
    #     include HasHcbCode
    #     set_hcb_code_type :WIRE_CODE
    #   end
    #
    # This generates:
    #   def hcb_code
    #     "HCB-#{TransactionGroupingEngine::Calculate::HcbCode::WIRE_CODE}-#{id}"
    #   end
    #
    #   def local_hcb_code
    #     @local_hcb_code ||= HcbCode.find_or_create_by(hcb_code:)
    #   end
    def set_hcb_code_type(code_constant)
      define_method(:hcb_code) do
        "HCB-#{TransactionGroupingEngine::Calculate::HcbCode.const_get(code_constant)}-#{id}"
      end

      define_method(:local_hcb_code) do
        @local_hcb_code ||= HcbCode.find_or_create_by(hcb_code:)
      end
    end
  end
end
