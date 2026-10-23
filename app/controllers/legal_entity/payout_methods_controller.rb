# frozen_string_literal: true


class LegalEntity
  class PayoutMethodsController < ApplicationController
    before_action :set_payout_method, only: [:update, :set_default, :archive]
    before_action :require_unlocked_method, only: [:update, :archive]

    def create
      authorize LegalEntity::PayoutMethod.new(legal_entity:), :create?

      service = LegalEntity::PayoutMethodService::Update.new(
        legal_entity:,
        details_type: params.dig(:user, :payout_method_type),
        details_attrs: details_params_for(params.dig(:user, :payout_method_type)),
        name: params.dig(:user, :payout_method_name),
        make_default: legal_entity.payout_methods.unarchived.none?
      )

      if service.run
        flash[:success] = "Payout method added."
        redirect_back_or_to settings_payouts_path
      else
        respond_to do |format|
          format.turbo_stream do
            assign_payout_settings_error(service.payout_method)
            render template: "legal_entity/payout_methods/create", status: :unprocessable_content
          end

          format.html do
            render_error_payout_settings(service.payout_method)
          end
        end
      end
    end

    def update
      authorize @payout_method

      service = LegalEntity::PayoutMethodService::Update.new(
        legal_entity: @payout_method.legal_entity,
        details_type: @payout_method.details_type,
        details_attrs: details_params_for(@payout_method.details_type),
        name: params.dig(:user, :payout_method_name),
        make_default: @payout_method.default?,
        replacing: @payout_method
      )

      if service.run
        flash[:success] = "Payout method updated."
        redirect_back_or_to settings_payouts_path
      else
        render_error_payout_settings(service.payout_method)
      end
    end

    def set_default
      authorize @payout_method

      @payout_method.update!(default: true)
      flash[:success] = "Default payout method updated."
      redirect_back_or_to settings_payouts_path
    end

    def archive
      authorize @payout_method

      # A default method can only be removed when it's the user's last active
      # method; otherwise they must promote another method to default first.
      if @payout_method.default? && legal_entity.payout_methods.unarchived.excluding(@payout_method).exists?
        flash[:error] = "Set another payout method as your default before removing this one."
        return redirect_back_or_to settings_payouts_path
      end

      draft_report = @payout_method.reimbursement_reports.where(aasm_state: :draft)

      @payout_method.archive!

      default = legal_entity.default_payout_method
      if draft_report.any?
        draft_report.find_each do |report|
          report.update!(legal_entity_payout_method: default)
          report.convert_report_currency!(default.currency) if default && report.mismatched_currency?
        end
      end

      flash[:success] = "Payout method removed."
      redirect_back_or_to settings_payouts_path
    end

    private

    # Per-method, report-aware lock: editing or removing a method is blocked only
    # while a report using it is in-flight (submitted → approved). Adding a new
    # method or pointing the default at a different record is always allowed and
    # never reaches this filter.
    def require_unlocked_method
      return unless @payout_method&.locked_by_processing_reimbursement_report?

      flash[:error] = "You can't change this payout method while a reimbursement is being processed."
      redirect_back_or_to settings_payouts_path
    end

    def render_error_payout_settings(payout_method)
      assign_payout_settings_error(payout_method)
      flash.now[:error] = payout_method.error_messages.to_sentence

      render template: "users/edit_payout", status: :unprocessable_content
    end

    def assign_payout_settings_error(payout_method)
      @legal_entity = payout_method.legal_entity || legal_entity
      @user = legal_entity&.users&.find_by(id: params[:user_id]) || current_user
      @payout_method = payout_method
      @legal_entities = @user.legal_entities
    end

    def legal_entity
      @legal_entity ||= @payout_method&.legal_entity ||
                        manageable_legal_entities&.find_by(id: params[:legal_entity_id]) ||
                        current_user&.personal_legal_entity
    end

    def manageable_legal_entities
      current_user&.admin? ? LegalEntity.all : current_user&.legal_entities
    end

    def set_payout_method
      scope = LegalEntity::PayoutMethod.unarchived.where(legal_entity: manageable_legal_entities)
      @payout_method = scope.find_by(id: params[:id])
      return if @payout_method

      skip_authorization
      flash[:error] = "Payout method not found."
      redirect_back_or_to settings_payouts_path
    end

    def details_params_for(type_name)
      LegalEntity::PayoutMethod.details_params_from(params, type_name)
    end

  end

end
