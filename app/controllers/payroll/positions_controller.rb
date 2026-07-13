# frozen_string_literal: true

module Payroll
  class PositionsController < ApplicationController
    include SetEvent

    before_action :set_event

    def show
      @position = @event.payroll_positions.find(params[:id])
      authorize @event, policy_class: Payroll::PositionPolicy
      @frame = params[:frame].present?
      @can_review = Payroll::PositionPolicy.new(current_user, @event).review?
      @invoices = @position.invoices.order(created_at: :desc)
      @payments = @position.payee.payments.order(created_at: :desc)
      render :show, layout: !@frame
    end

    def new
      authorize @event, policy_class: Payroll::PositionPolicy
      @payee = @event.payees.find_by_public_id(params[:payee_id]) if params[:payee_id].present?
      render layout: "transfer"
    end

    def create
      authorize @event, policy_class: Payroll::PositionPolicy

      @payee = @event.payees.find_by_public_id!(position_params[:payee_id])
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
        flash[:success] = "Contractor added"
        redirect_to event_contractors_path(event_id: @event.slug)
      else
        flash[:error] = @position.errors.full_messages.to_sentence
        render :new, layout: "transfer", status: :unprocessable_entity
      end
    end

    private

    def position_params
      params.require(:contractor).permit(:title, :rate, :starts_on, :ends_on, :purpose, :payee_id, file: [])
    end

  end
end
