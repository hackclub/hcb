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

      def initialize(user:, details_type:, details_attrs: {})
        @user = user
        @details_type = details_type
        @details_attrs = details_attrs || {}
      end

      def run
        @payout_method = build_payout_method
        apply_business_rules
        return false if @payout_method.errors.any?

        replaced_method = @user.default_payout_method

        # autosave: true on :details saves the detail record and the payout
        # method together, atomically, even inside the controller's transaction.
        saved = @payout_method.save
        repoint_failed_and_draft_reports(replaced_method) if saved
        saved
      end

      def run!
        run || raise(ActiveRecord::RecordInvalid, @payout_method)
      end

      def error_messages
        return [] unless @payout_method

        # Read base errors off the payout method (unsupported type, the Wise
        # guards) and field errors off the details record. Autosave also mirrors
        # the field errors onto the parent as "details.<attr>" ("Details routing
        # number must be 9 digits"); reading the child instead keeps the clean
        # "Routing number must be 9 digits" wording without duplication.
        (@payout_method.errors.full_messages_for(:base) +
          (@payout_method.details&.errors&.full_messages || [])).uniq
      end

      private

      def build_payout_method
        # Resolve the user-supplied type against the allowlist by name rather
        # than constantizing it, so arbitrary class names can never be loaded.
        details_class = LegalEntity::PayoutMethod::ALL_METHODS.find { |klass| klass.name == @details_type }
        pm = LegalEntity::PayoutMethod.new(legal_entity: @user.personal_legal_entity, default: true)
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

      def repoint_failed_and_draft_reports(replaced_method)
        return unless replaced_method

        @user.reimbursement_reports
             .joins(:payout_holding)
             .where(reimbursement_payout_holdings: { aasm_state: :failed })
             .where(legal_entity_payout_method_id: replaced_method.id)
             .update(legal_entity_payout_method: @payout_method)

        @user.reimbursement_reports
             .where(aasm_state: :draft)
             .where(legal_entity_payout_method_id: replaced_method.id)
             .update(legal_entity_payout_method: @payout_method)
      end

      def switching_to_wise_while_processing?
        # Only reports that still track the user's default (no snapshotted
        # payout method) would be flipped to Wise by this change; reports with
        # their own snapshot keep their original method and are unaffected.
        @payout_method.details.is_a?(LegalEntity::PayoutMethod::WiseTransfer) &&
          !@user.default_payout_method&.details.is_a?(LegalEntity::PayoutMethod::WiseTransfer) &&
          @user.reimbursement_reports.where(aasm_state: PROCESSING_STATES, legal_entity_payout_method_id: nil).any?
      end

    end
  end

end
