# frozen_string_literal: true

class PayeesController < ApplicationController
  include SetEvent

  before_action :set_event, only: [:index, :create, :update, :archive]
  before_action :set_payee, only: [:choose_legal_entity, :set_legal_entity]

  class InvalidManualPayeeEntityType < StandardError; end

  def index
    authorize @event
    all = @event.payees.not_archived.includes(:legal_entity, :payments)
    payees = params[:q].present? ? all.search(params[:q]) : all
    payees = payees.order(created_at: :desc).limit(15)

    selected = all.find_by_hashid(params[:payee_id]) if params[:payee_id].present?
    @payees = [selected, *payees.to_a].compact.uniq.first(15)

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

      redirect_to helpers.new_recipient_transfer_path(params[:destination], @event, payee_id: payee.hashid)
    end
  rescue ActiveRecord::RecordInvalid, InvalidManualPayeeEntityType => e
    flash[:error] = e.message
    redirect_to helpers.new_recipient_transfer_path(params[:destination], @event)
  end

  def update
    payee = @event.payees.not_archived.find_by_hashid!(params[:id])
    authorize payee

    if payee.update(payee_params)
      flash[:success] = "Recipient updated."
      redirect_to helpers.new_recipient_transfer_path(params[:destination], @event, payee_id: payee.hashid)
    else
      flash[:error] = payee.errors.full_messages.to_sentence
      redirect_to helpers.new_recipient_transfer_path(params[:destination], @event, payee_id: payee.hashid, edit_payee: true)
    end
  end

  def archive
    payee = @event.payees.not_archived.find_by_hashid!(params[:id])
    authorize payee

    payee.archive!

    flash[:success] = "Recipient archived."
    redirect_to helpers.new_recipient_transfer_path(params[:destination], @event)
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
