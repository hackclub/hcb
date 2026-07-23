# frozen_string_literal: true

module Admin
  class TaxFormsController < Admin::BaseController
    def index
      @page = params[:page] || 1
      @per = params[:per] || 20

      relation = Tax::Form.includes(:legal_entity)

      @q = params[:q].presence
      if @q
        relation = relation.left_joins(legal_entity: :users).where("legal_entities.name ILIKE :q OR users.full_name ILIKE :q OR users.email ILIKE :q", q: "%#{Tax::Form.sanitize_sql_like(@q)}%").distinct
      end

      @state = params[:state].presence
      relation = relation.where(aasm_state: @state) if @state

      @form_type = params[:form_type].presence
      relation = relation.where(form_type: @form_type) if @form_type

      @tax_forms = relation.order(created_at: :desc).page(@page).per(@per)
    end

  end
end
