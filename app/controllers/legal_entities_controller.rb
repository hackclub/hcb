# frozen_string_literal: true

class LegalEntitiesController < ApplicationController
  before_action :set_legal_entity, only: [:show, :switch]

  def show
    authorize @legal_entity
  end

  def switch
    authorize @legal_entity

    new_tax_form = Tax::Form.find(params[:new_tax_form_id])
    authorize new_tax_form, :switch_legal_entity?

    new_le = nil

    ActiveRecord::Base.transaction do
      @legal_entity.archive!

      new_le = LegalEntity.create!(
        name: params[:name],
        tin_hash: new_tax_form.tin_hash,
        entity_type: new_tax_form.inferred_entity_type,
        users: @legal_entity.users
      )

      new_tax_form.update!(legal_entity: new_le)

      @legal_entity.payments.pending_legal_entity.each do |payment|
        next unless payment.payee.archived?

        new_payee = payment.event.payees.create!(
          display_name: payment.payee.display_name,
          email: payment.payee.email,
          legal_entity: new_le
        )

        payee.payments.pending_legal_entity.each do |payee_payment|
          payee_payment.update!(payee: new_payee)
        end

        payment.payee.archive!
      end
    end

    redirect_to legal_entity_path(new_le)
  end

  def create_from_tax_form
    tax_form = Tax::Form.find(params[:new_tax_form_id])
    authorize tax_form, :create_legal_entity?

    ActiveRecord::Base.transaction do
      new_le = LegalEntity.create!(
        name: params[:name],
        tin_hash: tax_form.tin_hash,
        entity_type: tax_form.inferred_entity_type,
        users: [current_user]
      )

      tax_form.update!(new_le)
    end

    redirect_to legal_entity_path(new_le)
  end

  private

  def set_legal_entity
    @legal_entity = LegalEntity.find_by_hashid!(params[:id])
  end

end
