# frozen_string_literal: true

module Tax
  class FormsController < ApplicationController
    def show
      @form = Tax::Form.find_by_hashid(params[:id])
      @legal_entity = @form.legal_entity

      authorize @form
    end

    def create
      @legal_entity = LegalEntity.find_by_hashid(params[:legal_entity_id])
      authorize @legal_entity, policy_class: Tax::FormPolicy

      tax_form = @legal_entity.tax_forms.create!(external_service: :taxbandits)
      tax_form.send!

      redirect_to tax_form_path(tax_form)
    end

  end
end
