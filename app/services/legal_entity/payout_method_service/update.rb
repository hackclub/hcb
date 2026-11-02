# frozen_string_literal: true

class LegalEntity
  module PayoutMethodService
    # Builds, validates, and persists a payout method for a given legal entity
    # (a user's personal legal entity, or another entity they belong to).
    # Encapsulates the business rules that previously lived across
    # User#build_default_payout_method, User#valid_payout_method, and the
    # UsersController#update transaction.
    #
    # On failure, #run returns false and the (unsaved) payout method, exposed
    # via #payout_method, carries the relevant errors.
    class Update
      attr_reader :payout_method

      def initialize(legal_entity:, details_type:, details_attrs: {}, name: nil, make_default: true, replacing: nil)
        @legal_entity = legal_entity
        @details_type = details_type
        @details_attrs = details_attrs || {}
        @name = name&.strip.presence
        @make_default = make_default
        @replacing = replacing
      end

      def run
        @payout_method = build_payout_method
        apply_business_rules
        return false if @payout_method.errors.any?

        # autosave: true on :details saves the detail record and the payout
        # method together, atomically, even inside the controller's transaction.
        saved = @payout_method.save
        if saved
          repoint_failed_and_draft_reports if @replacing || @make_default
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
        details_class = LegalEntity::PayoutMethod.details_class_for(@details_type)
        pm = LegalEntity::PayoutMethod.new(legal_entity: @legal_entity, default: @make_default, name: @name)
        pm.details = details_class.new(preserved_details_attrs(details_class)) if details_class
        pm
      end

      # Masked fields (e.g. ACH account / routing numbers) are shown masked in the
      # edit form. If a value comes back still masked, the user didn't change it.
      # keep the existing value instead of overwriting it with the mask. This lets
      # a nickname-only edit succeed without re-entering the account details.
      def preserved_details_attrs(details_class)
        attrs = @details_attrs.dup
        existing = @replacing&.details
        return attrs unless existing.is_a?(details_class)

        attrs.each do |field, value|
          attrs[field] = existing.public_send(field) if value.to_s.include?("•")
        end
        attrs
      end

      def apply_business_rules
        if @payout_method.details.nil?
          @payout_method.errors.add(:base, "is invalid. Please choose another method.")
        end
      end

      def repoint_failed_and_draft_reports
        reports = Reimbursement::Report.where(user: @legal_entity.users)

        failed = reports.joins(:payout_holding).where(reimbursement_payout_holdings: { aasm_state: :failed })
        draft = reports.where(aasm_state: :draft)

        # update! runs validations and records the change in paper_trail; each
        # is wrapped in safely so a single report that can't be repointed is
        # reported rather than silently skipped, without aborting the user's
        # payout-method change or the other repoints.
        (failed + draft).each do |report|
          safely do
            ActiveRecord::Base.transaction do
              report.update!(legal_entity_payout_method: @payout_method)
              report.convert_report_currency!(@payout_method.currency) if report.mismatched_currency?
              report.payout_holding.mark_settled! if report.payout_holding&.failed?
            end
          end
        end
      end

    end
  end

end
