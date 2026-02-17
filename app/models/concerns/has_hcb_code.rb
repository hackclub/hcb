# frozen_string_literal: true

module HasHcbCode
  extend ActiveSupport::Concern

  class_methods do
    # Defines `hcb_code` and `local_hcb_code` methods on the model.
    #
    # @param code_constant [String] The HCB code constant (e.g., "200" for donations)
    # @param persisted_only [Boolean] If true, `local_hcb_code` returns nil when the record is not yet persisted
    # @param eager_create [Boolean] If true, adds an `after_create` callback to eagerly create the HcbCode record
    def has_hcb_code(code_constant, persisted_only: false, eager_create: false)
      define_method(:hcb_code) do
        "HCB-#{code_constant}-#{id}"
      end

      if persisted_only
        define_method(:local_hcb_code) do
          return nil unless persisted?

          @local_hcb_code ||= HcbCode.find_or_create_by(hcb_code:)
        end
      else
        define_method(:local_hcb_code) do
          @local_hcb_code ||= HcbCode.find_or_create_by(hcb_code:)
        end
      end

      after_create :local_hcb_code if eager_create
    end
  end
end
