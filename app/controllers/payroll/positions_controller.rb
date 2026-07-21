# frozen_string_literal: true

module Payroll
  class PositionsController < ApplicationController
    include SetEvent

    CONTRACT_RELEVANT_ATTRIBUTES = %w[title rate_cents rate_unit start_date end_date description].freeze

    before_action :set_event, except: [:onboarding]
    before_action :set_position, only: [:edit, :update, :contract]

    def show
      @position = @event.payroll_positions.find(params[:id])
      authorize @position
      @frame = params[:frame].present?
      @can_review = Payroll::PositionPolicy.new(current_user, @event).review?
      @invoices = @position.invoices.order(created_at: :desc)
      @payments = @position.payee.payments.order(created_at: :desc)

      @position.contract&.party(:organizer)&.sync_with_docuseal

      render :show, layout: !@frame
    end

    def onboarding
      @position = Payroll::Position.find_by_hashid!(params[:id])
      authorize @position

      @contractor_party = @position.contract&.party(:contractor)
      @contractor_party.sync_with_docuseal
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
        rate_unit: position_params[:rate_unit].presence || "hour",
        start_date: position_params[:starts_on],
        end_date: position_params[:ends_on],
        description: position_params[:purpose]
      )
      if (attachment = Array(position_params[:file]).compact_blank.first)
        @position.file.attach(attachment)
      end

      if @position.save
        if send_contract_for_position!
          redirect_to contract_event_payroll_position_path(event_id: @event.slug, id: @position.id)
        else
          redirect_to edit_event_payroll_position_path(event_id: @event.slug, id: @position.id)
        end
      else
        flash[:error] = @position.errors.full_messages.to_sentence
        render :new, layout: "transfer", status: :unprocessable_entity
      end
    end

    # Display-only: never creates or sends a contract as a side effect of a
    # GET, so this action stays safe (idempotent, no external calls). Sending
    # happens from #create/#update instead.
    def contract
      authorize @position
      @contract = @position.contracts.not_voided.order(created_at: :desc).first

      if @contract.nil?
        flash[:error] = "We couldn't send this contract for signing. Please review the details and save again to retry."
        redirect_to edit_event_payroll_position_path(event_id: @event.slug, id: @position.id) and return
      end

      @organizer_party = @contract.party(:organizer)
      @can_sign_as_organizer = @organizer_party.user_id == current_user.id
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
        rate_unit: position_params[:rate_unit].presence || "hour",
        start_date: position_params[:starts_on],
        end_date: position_params[:ends_on],
        description: position_params[:purpose]
      )
      attachment = Array(position_params[:file]).compact_blank.first
      @position.file.attach(attachment) if attachment

      will_void_contract = contract_terms_changed?(attachment_changed: attachment.present?)
      authorize @position, :void_pending_contract? if will_void_contract

      if @position.save
        void_pending_contract! if will_void_contract

        if send_contract_for_position!
          redirect_to contract_event_payroll_position_path(event_id: @event.slug, id: @position.id)
        else
          redirect_to edit_event_payroll_position_path(event_id: @event.slug, id: @position.id)
        end
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

    def contract_terms_changed?(attachment_changed:)
      attachment_changed || (@position.changes.keys & CONTRACT_RELEVANT_ATTRIBUTES).any?
    end

    # At most one non-voided contract exists per position (enforced by
    # Contract#one_non_void_contract), so there's only ever one to void here.
    def void_pending_contract!
      contract = @position.contracts.where(aasm_state: [:pending, :sent]).first
      contract&.tap { |c| c.mark_voided!(reissuing: true) }
    end

    # Ensures the position has an active (not-voided) contract, returning
    # whether one exists afterwards. No-ops (returns true) if one already
    # exists (e.g. an edit that didn't change contract-relevant fields), so
    # this is safe to call unconditionally after save — it also doubles as
    # the retry path if a previous send attempt failed. Looking up the
    # unlinked voided contract (rather than requiring the caller to pass one
    # in) means a retry after a failed send still reissues off the right
    # contract, even across separate requests.
    def send_contract_for_position!
      return true if @position.contracts.not_voided.exists?

      reissue_of = @position.contracts.where(aasm_state: :voided).where.missing(:reissued_contract).order(created_at: :desc).first
      @position.send_contract(organizer_user: current_user, reissue_of:)
      true
    rescue Faraday::Error => e
      Rails.error.report(e, context: { payroll_position_id: @position.id })
      flash[:error] = "We couldn't send this contract for signing right now. Please try again in a moment."
      false
    end

    def position_params
      params.require(:contractor).permit(:title, :rate, :rate_unit, :starts_on, :ends_on, :purpose, :payee_id, file: [])
    end

  end
end
