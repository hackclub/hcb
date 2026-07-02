# frozen_string_literal: true

class LegalEntitiesController < ApplicationController
  before_action :set_legal_entity

  def show
    authorize @legal_entity
  end

  private

  def set_legal_entity
    @legal_entity = LegalEntity.find_by_hashid!(params[:id])
  end

end
