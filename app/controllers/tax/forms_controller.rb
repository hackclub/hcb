# frozen_string_literal: true

module Tax
  class FormsController < ApplicationController
    def show
      @form = Tax::Form.find_by_hashid(params[:id])
      authorize @form
    end

    def create
      @legal_entity = LegalEntity.find_by_hashid(params[:legal_entity_id])
      authorize @legal_entity

      tax_form = @legal_entity.tax_forms.create!(external_service: :taxbandits)

      redirect_to tax_form_path(tax_form)
    end

  end
end
