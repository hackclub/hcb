# frozen_string_literal: true

module HasHcbCode
  extend ActiveSupport::Concern

  class_methods do
    # Defines `hcb_code` and `local_hcb_code` methods on the model.
    #
    # @param code_constant [String] The HCB code constant (e.g., "200" for donations)
    # @param identifier [Symbol] The attribute the code is suffixed with (defaults to `id`)
    # @param persisted_only [Boolean] If true, `local_hcb_code` returns nil when the record is not yet persisted
    # @param eager_create [Boolean] If true, adds an `after_create` callback to eagerly create the HcbCode record
    def has_hcb_code(code_constant, identifier: :id, persisted_only: false, eager_create: false)
      define_method(:hcb_code) do
        "HCB-#{code_constant}-#{public_send(identifier)}"
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

  # The methods below only need `hcb_code` and `local_hcb_code`, so a model that
  # stores its code in an `hcb_code` column (BankFee, Reimbursement::ExpensePayout)
  # includes the concern without calling `has_hcb_code`.

  def canonical_transactions
    @canonical_transactions ||= CanonicalTransaction.where(hcb_code:)
  end

  def pending_expired?
    local_hcb_code.has_pending_expired?
  end

  # Memo / statement descriptor sent to the bank or Stripe so the resulting
  # transaction can be matched back to this record's HCB code.
  def short_code_memo
    "HCB-#{local_hcb_code.short_code}"
  end
end
