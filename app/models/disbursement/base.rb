# frozen_string_literal: true

class Disbursement
  module Base
    extend ActiveSupport::Concern

    included do
      attr_reader :disbursement

      delegate :id, :name, :source_event, :destination_event, :public_id,
               :destination_subledger, :source_subledger, :to_model,
               :fulfilled?, :reviewing?, :state,
               :requested_by, :card_grant, :inter_event_transfer?,
               :processed?, :pending?, :rejected?, :scheduled?, :may_mark_rejected?,
               :state_text, :state_icon,
               :special_appearance, :special_appearance_name, :special_appearance?,
               :transferred_at, :created_at, :scheduled_on,
               :fulfilled_by, :fee_waived?, :to_param, :special_appearance_memo,
               :v4_api_state, :outgoing_disbursement, :incoming_disbursement,
               to: :disbursement
    end

    def initialize(disbursement)
      raise ArgumentError, "Expected Disbursement" unless disbursement.is_a?(Disbursement)

      @disbursement = disbursement
    end

    def canonical_transactions
      @canonical_transactions ||= CanonicalTransaction.where(hcb_code:)
    end

    def canonical_pending_transactions
      @canonical_pending_transactions ||= CanonicalPendingTransaction.where(hcb_code:)
    end

    def pending_expired?
      local_hcb_code.has_pending_expired?
    end

    def transaction_memo
      "HCB-#{local_hcb_code.short_code}"
    end

    def local_hcb_code
      @local_hcb_code ||= HcbCode.find_or_create_by(hcb_code:)
    end
  end

end
