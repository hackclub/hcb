# frozen_string_literal: true

module Admin
  class LegalEntitiesController < Admin::BaseController
    def index
      @page = params[:page] || 1
      @per = params[:per] || 20

      relation = LegalEntity.includes(:users, :managing_event, :latest_tax_form)

      @q = params[:q].presence
      if @q
        relation = relation.left_joins(:users).where("legal_entities.name ILIKE :q OR users.full_name ILIKE :q OR users.email ILIKE :q", q: "%#{LegalEntity.sanitize_sql_like(@q)}%").distinct
      end

      @entity_type = params[:entity_type].presence
      relation = relation.where(entity_type: @entity_type) if @entity_type

      @managed = params[:managed] == "1"
      relation = relation.managed if @managed

      @archived = params[:archived] == "1"
      relation = relation.where.not(archived_at: nil) if @archived

      @legal_entities = relation.order(created_at: :desc).page(@page).per(@per)
    end

  end
end
