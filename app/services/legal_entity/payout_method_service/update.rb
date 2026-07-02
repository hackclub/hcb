# frozen_string_literal: true

class LegalEntity
  module PayoutMethodService
    # Builds, validates, and persists a user's default personal-legal-entity
    # payout method. Encapsulates the business rules that previously lived
    # across User#build_default_payout_method, User#valid_payout_method, and
    # the UsersController#update transaction.
    #
    # On failure, #run returns false and the (unsaved) payout method, exposed
    # via #payout_method, carries the relevant errors.
    class Update
      attr_reader :payout_method

      def initialize(user:, details_type:, details_attrs: {}, make_default: true, replacing: nil)
        @user = user
        @details_type = details_type
        @details_attrs = details_attrs || {}
        @make_default = make_default
        @replacing = replacing
      end

      def run
        @payout_method = build_payout_method
        apply_business_rules
        return false if @payout_method.errors.any?

        replaced_method = @replacing

        # autosave: true on :details saves the detail record and the payout
        # method together, atomically, even inside the controller's transaction.
        saved = @payout_method.save
        if saved
          repoint_failed_and_draft_reports(replaced_method) if @replacing || @make_default
          @replacing.archive! if @replacing && @replacing != @payout_method
        end
        saved
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
        if @payout_method.details.nil?
          @payout_method.errors.add(:base, "is invalid. Please choose another method.")
        end
      end

      def repoint_failed_and_draft_reports(replaced_method)
        on_replaced_method = @user.reimbursement_reports.where(legal_entity_payout_method_id: replaced_method&.id)

        failed = on_replaced_method.joins(:payout_holding).where(reimbursement_payout_holdings: { aasm_state: :failed })
        draft = on_replaced_method.where(aasm_state: :draft)

        # update! runs validations and records the change in paper_trail; each
        # is wrapped in safely so a single report that can't be repointed is
        # reported rather than silently skipped, without aborting the user's
        # payout-method change or the other repoints.
        (failed + draft).each do |report|
          safely do
            report.convert_report_currency!(@payout_method.currency) if report.currency != @payout_method.currency
            report.update!(legal_entity_payout_method: @payout_method)
          end
        end
      end

    end
  end

end
