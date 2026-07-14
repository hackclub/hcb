# frozen_string_literal: true

class LegalEntitiesController < ApplicationController
  before_action :set_legal_entity, only: [:show, :replace]

  def show
    authorize @legal_entity
  end

  def replace
    authorize @legal_entity

    new_tax_form = @legal_entity.tax_forms.find(params[:new_tax_form_id])
    authorize new_tax_form, :switch_legal_entity?

    if new_tax_form.inferred_entity_type.to_s != @legal_entity.entity_type
      flash[:error] = "Can't switch to a legal entity of a different type"
      redirect_to legal_entity_path(@legal_entity)
      return
    end

    new_le = nil

    ActiveRecord::Base.transaction do
      @legal_entity.archive!

      new_le = LegalEntity.create!(
        name: @legal_entity.name,
        tin_hash: new_tax_form.tin_hash,
        entity_type: new_tax_form.inferred_entity_type,
        users: @legal_entity.users
      )

      new_tax_form.update!(legal_entity: new_le)

      migrate_pending_payments(from_le: @legal_entity, to_le: new_le)
    end

    redirect_to legal_entity_path(new_le)
  end

  def create_from_tax_form
    tax_form = Tax::Form.find(params[:new_tax_form_id])
    authorize tax_form, :create_legal_entity?

    old_le = LegalEntity.find_by(id: params[:old_le_id])
    authorize old_le, :switch? if old_le.present?

    new_le = nil

    ActiveRecord::Base.transaction do
      new_le = LegalEntity.create!(
        name: params[:name],
        tin_hash: tax_form.tin_hash,
        entity_type: tax_form.inferred_entity_type,
        users: [current_user]
      )

      tax_form.update!(legal_entity: new_le)

      migrate_pending_payments(from_le: old_le, to_le: new_le) if old_le.present?
    end

    redirect_to legal_entity_path(new_le)
  end

  private

  def set_legal_entity
    @legal_entity = LegalEntity.find_by_hashid!(params[:id])
  end

  def migrate_pending_payments(from_le:, to_le:)
    from_le.payees.includes(:payments).find_each do |payee|
      next if payee.payments.pending_legal_entity.none?

      new_payee = payee.event.payees.create!(
        display_name: payee.display_name,
        email: payee.email,
        legal_entity: to_le
      )

      payee.payments.pending_legal_entity.each do |payment|
        payment.update!(payee: new_payee)
      end

      payee.archive!
    end
  end

end
