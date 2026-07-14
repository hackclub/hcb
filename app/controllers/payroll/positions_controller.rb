# frozen_string_literal: true

module Payroll
  class PositionsController < ApplicationController
    include SetEvent

    before_action :set_event
    before_action :set_position, only: [:edit, :update, :contract]

    def show
      @position = @event.payroll_positions.find(params[:id])
      authorize @position
      @frame = params[:frame].present?
      @can_review = Payroll::PositionPolicy.new(current_user, @event).review?
      @invoices = @position.invoices.order(created_at: :desc)
      @payments = @position.payee.payments.order(created_at: :desc)
      render :show, layout: !@frame
    end

    def new
      authorize @event, policy_class: Payroll::PositionPolicy
      @payee = @event.payees.not_archived.find_by_hashid(params[:payee_id]) if params[:payee_id].present?
      render layout: "transfer"
    end

    def create
      authorize @event, policy_class: Payroll::PositionPolicy

      @payee = @event.payees.not_archived.find_by_hashid!(position_params[:payee_id])
      @position = @payee.payroll_positions.build(
        title: position_params[:title],
        rate_cents: Monetize.parse(position_params[:rate]).cents,
        start_date: position_params[:starts_on],
        end_date: position_params[:ends_on],
        description: position_params[:purpose]
      )
      if (attachment = Array(position_params[:file]).compact_blank.first)
        @position.file.attach(attachment)
      end

      if @position.save
        redirect_to contract_event_payroll_position_path(event_id: @event.slug, id: @position.id)
      else
        flash[:error] = @position.errors.full_messages.to_sentence
        render :new, layout: "transfer", status: :unprocessable_entity
      end
    end

    def contract
      authorize @position
      @contract = @position.contracts.not_voided.order(created_at: :desc).first
      @contract ||= @position.send_contract(organizer_user: current_user)
      @organizer_party = @contract.party(:organizer)
      render layout: "transfer"
    end

    def edit
      authorize @position
      @payee = @position.payee
      render layout: "transfer"
    end

    def update
      authorize @position

      @position.assign_attributes(
        title: position_params[:title],
        rate_cents: Monetize.parse(position_params[:rate]).cents,
        start_date: position_params[:starts_on],
        end_date: position_params[:ends_on],
        description: position_params[:purpose]
      )
      if (attachment = Array(position_params[:file]).compact_blank.first)
        @position.file.attach(attachment)
      end

      if @position.save
        void_pending_contracts!
        redirect_to contract_event_payroll_position_path(event_id: @event.slug, id: @position.id)
      else
        @payee = @position.payee
        flash[:error] = @position.errors.full_messages.to_sentence
        render :edit, layout: "transfer", status: :unprocessable_entity
      end
    end

    private

    def set_position
      @position = @event.payroll_positions.find(params[:id])
    end

    def void_pending_contracts!
      @position.contracts.where(aasm_state: [:pending, :sent]).find_each do |contract|
        contract.mark_voided!(reissuing: true)
      end
    end

    def position_params
      params.require(:contractor).permit(:title, :rate, :starts_on, :ends_on, :purpose, :payee_id, file: [])
    end

  end
end
