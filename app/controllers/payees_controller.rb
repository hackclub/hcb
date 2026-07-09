# frozen_string_literal: true

class PayeesController < ApplicationController
  include SetEvent

  before_action :set_event, only: [:index, :create, :update, :destroy]
  before_action :set_payee, only: [:choose_legal_entity, :set_legal_entity]

  class InvalidManualPayeeEntityType < StandardError; end

  def index
    authorize @event
    scope = @event.payees.not_archived.includes(:legal_entity, :payments)
    payees = params[:q].present? ? scope.search(params[:q]) : scope
    payees = payees.order(created_at: :desc).limit(15).to_a

    selected = @event.payees.not_archived.includes(:legal_entity, :payments).find_by_public_id(params[:payee_id]) if params[:payee_id].present?
    @payees = [selected, *payees].compact.uniq

    render layout: false
  end

  def create
    manual = params[:manual] == "true"

    payee = @event.payees.build(display_name: params[:name], email: params[:email])
    authorize payee

    ActiveRecord::Base.transaction do
      if manual
        payee.legal_entity = LegalEntity.create!(
          managing_event: @event,
          entity_type: manual_payee_entity_type,
          name: params[:name]
        )
      end

      payee.save!

      redirect_to new_event_payment_path(event_id: @event.slug, payee_id: payee.public_id)
    end
  rescue ActiveRecord::RecordInvalid, InvalidManualPayeeEntityType => e
    flash[:error] = e.message
    redirect_to new_event_payment_path(event_id: @event.slug)
  end

  def update
    payee = @event.payees.not_archived.find_by_public_id!(params[:id])
    authorize payee

    if payee.update(payee_params)
      flash[:success] = "Recipient updated."
      redirect_to new_event_payment_path(event_id: @event.slug, payee_id: payee.public_id)
    else
      flash[:error] = payee.errors.full_messages.to_sentence
      redirect_to new_event_payment_path(event_id: @event.slug, payee_id: payee.public_id, edit_payee: true)
    end
  end

  def archive
    payee = @event.payees.not_archived.find_by_public_id!(params[:id])
    authorize payee

    payee.archive!

    flash[:success] = "Recipient archived."
    redirect_to new_event_payment_path(event_id: @event.slug)
  end

  def choose_legal_entity
    authorize @payee

    if @payee.legal_entity.present?
      redirect_to legal_entity_path(@payee.legal_entity)
      return
    end

    @legal_entities = current_user.legal_entities
  end

  def set_legal_entity
    authorize @payee

    le = current_user.legal_entities.find(params[:legal_entity_id])
    if le.tin_banned?
      flash[:error] = "This legal entity is banned."
      redirect_back_or_to choose_legal_entity_payee_path(@payee)
      return
    end

    @payee.update!(legal_entity: le)

    flash[:success] = "Legal entity successfully assigned"

    redirect_to legal_entity_path(le)
  end

  private

  def payee_params
    params.require(:payee).permit(:display_name, :email)
  end

  def set_payee
    @payee = Payee.find_by_hashid!(params[:id])
  end

  def manual_payee_entity_type
    entity_type = params[:payee_entity_type].presence
    return entity_type if LegalEntity.entity_types.key?(entity_type)

    raise InvalidManualPayeeEntityType, "Select whether the recipient is an individual or a business."
  end

end
