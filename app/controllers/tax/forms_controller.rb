# frozen_string_literal: true

module Tax
  class FormsController < ApplicationController
    before_action :set_form, only: [:show, :sync, :discard]

    def show
      authorize @form

      @form.sync_with_taxbandits

      if @form.completed?
        flash[:success] = "This form has been completed"
        redirect_to legal_entity_path(@form.legal_entity)
        return
      end
    end

    def create
      @legal_entity = LegalEntity.find_by_hashid(params[:legal_entity_id])
      authorize @legal_entity, policy_class: Tax::FormPolicy

      if @legal_entity.mismatched_tax_form.present?
        flash[:error] = "Pick an option before starting a new tax form"
        redirect_to legal_entity_path(@form.legal_entity)
        return
      end

      tax_form = @legal_entity.tax_forms.create!(external_service: :taxbandits)
      tax_form.send!

      redirect_to tax_form_path(tax_form)
    end

    def sync
      authorize @form

      @form.sync_with_taxbandits

      if @form.completed?
        redirect_to legal_entity_path(@form.legal_entity)
      else
        flash[:error] = "Complete the form before continuing"
        redirect_back_or_to tax_form_path(@form)
      end
    end

    def discard
      authorize @form

      @form.mark_discarded!

      redirect_to legal_entity_path(@form.legal_entity)
    end

    private

    def set_form
      @form = Tax::Form.find_by_hashid!(params[:id])
      @legal_entity = @form.legal_entity
    end

  end
end
