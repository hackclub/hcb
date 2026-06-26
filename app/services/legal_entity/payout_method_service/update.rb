# frozen_string_literal: true

class LegalEntity
  module PayoutMethodService
    # Builds, validates, and persists a user's default personal-legal-entity
    # payout method. Encapsulates the business rules that previously lived
    # across User#build_default_payout_method, User#valid_payout_method,
    # User#can_update_payout_method?, and the UsersController#update transaction.
    #
    # On failure, #run returns false and the (unsaved) payout method, exposed
    # via #payout_method, carries the relevant errors.
    class Update
      # Report states that count as "being processed" for the purpose of
      # blocking a switch to Wise.
      PROCESSING_STATES = %i[submitted reimbursement_requested reimbursement_approved].freeze

      attr_reader :payout_method

      def initialize(user:, details_type:, details_attrs: {}, make_default: true)
        @user = user
        @details_type = details_type
        @details_attrs = details_attrs || {}
        @make_default = make_default
      end

      def run
        @payout_method = build_payout_method
        apply_business_rules
        return false if @payout_method.errors.any?

        # autosave: true on :details saves the detail record and the payout
        # method together, atomically, even inside the controller's transaction.
        @payout_method.save
      end

      def run!
        run || raise(ActiveRecord::RecordInvalid, @payout_method)
      end

      def error_messages
        @payout_method&.error_messages || []
      end

      private

      def build_payout_method
        # Resolve the user-supplied type against the allowlist by name rather
        # than constantizing it, so arbitrary class names can never be loaded.
        details_class = LegalEntity::PayoutMethod::ALL_METHODS.find { |klass| klass.name == @details_type }
        pm = LegalEntity::PayoutMethod.new(legal_entity: @user.personal_legal_entity, default: @make_default)
        pm.details = details_class.new(@details_attrs) if details_class
        pm
      end

      def apply_business_rules
        unless @user.can_update_payout_method?
          @payout_method.errors.add(:base, "can't be changed while a reimbursement is being processed. Please reach out to the HCB team if you need this changed.")
          return
        end

        if @payout_method.details.nil?
          @payout_method.errors.add(:base, "is invalid. Please choose another method.")
          return
        end

        if switching_to_wise_while_processing?
          @payout_method.errors.add(:base, "cannot be changed to Wise transfer with reports that are being processed. Please reach out to the HCB team if you need this changed.")
        end
      end

      def switching_to_wise_while_processing?
        @payout_method.details.is_a?(LegalEntity::PayoutMethod::WiseTransfer) &&
          !@user.default_payout_method&.details.is_a?(LegalEntity::PayoutMethod::WiseTransfer) &&
          @user.reimbursement_reports.where(aasm_state: PROCESSING_STATES).any?
      end

    end
  end

end
