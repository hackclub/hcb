# frozen_string_literal: true

class PayeesController < ApplicationController
  include SetEvent

  class InvalidManualPayeeEntityType < StandardError; end

  before_action :set_event

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

      redirect_to new_event_payment_path(event_id: @event.slug, payee_id: payee.id, manual: params[:manual])
    end
  rescue ActiveRecord::RecordInvalid, InvalidManualPayeeEntityType => e
    redirect_to new_event_payment_path(event_id: @event.slug, manual: params[:manual]),
                alert: e.message
  end

  private

  def manual_payee_entity_type
    entity_type = params[:payee_entity_type].presence
    return entity_type if LegalEntity.entity_types.key?(entity_type)

    raise InvalidManualPayeeEntityType, "Select whether the recipient is an individual or a business."
  end

end
