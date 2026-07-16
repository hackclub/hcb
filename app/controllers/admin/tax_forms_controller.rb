# frozen_string_literal: true

module Admin
  class TaxFormsController < Admin::BaseController
    def index
      @page = params[:page] || 1
      @per = params[:per] || 20

      relation = Tax::Form.includes(:legal_entity)

      @state = params[:state].presence
      relation = relation.where(aasm_state: @state) if @state

      @form_type = params[:form_type].presence
      relation = relation.where(form_type: @form_type) if @form_type

      @count = relation.count
      @tax_forms = relation.order(created_at: :desc).page(@page).per(@per)
    end

  end
end
