# frozen_string_literal: true

class PayeesController < ApplicationController
  include SetEvent

  before_action :set_event, only: [:index, :create]
  before_action :set_payee, only: [:choose_legal_entity, :set_legal_entity]

  class InvalidManualPayeeEntityType < StandardError; end

  def index
    authorize @event
    @payees = params[:q].present? ? @event.payees.search(params[:q]) : @event.payees
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

      redirect_to new_event_payment_path(event_id: @event.slug, payee_id: payee.id)
    end
  rescue ActiveRecord::RecordInvalid, InvalidManualPayeeEntityType => e
    redirect_to new_event_payment_path(event_id: @event.slug), alert: e.message
  end

  def choose_legal_entity
    authorize @payee

    if @payee.legal_entity.present?
      if @payee.legal_entity.payable?
        redirect_to settings_payouts_path
      else
        redirect_to legal_entity_path(@payee.legal_entity)
      end

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

    if le.payable?
      redirect_to settings_payouts_path
    else
      redirect_to legal_entity_path(le)
    end
  end

  private

  def set_payee
    @payee = Payee.find_by_hashid!(params[:id])
  end

  def manual_payee_entity_type
    entity_type = params[:payee_entity_type].presence
    return entity_type if LegalEntity.entity_types.key?(entity_type)

    raise InvalidManualPayeeEntityType, "Select whether the recipient is an individual or a business."
  end

end
