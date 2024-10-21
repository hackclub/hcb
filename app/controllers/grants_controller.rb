# frozen_string_literal: true

class GrantsController < ApplicationController
  include SetEvent

  before_action :set_event, only: [:index, :new, :create]

  skip_before_action :signed_in_user, only: [:show]
  skip_after_action :verify_authorized, only: [:show]

  def index
    @grants = @event.grants.order(created_at: :desc)

    authorize @event, policy_class: GrantPolicy
  end

  def new
    @grant = @event.grants.build

    authorize @grant
  end

  def create
    @grant = @event.grants.build(grant_params.merge(submitted_by: current_user))

    authorize @grant

    @grant.save!

    redirect_to event_grants_path(@event), flash: { success: "Your grant has been submitted!" }

  rescue => e
    flash.now[:error] = e.message
    notify_airbrake(e)
    render "new", status: :unprocessable_entity
  end

  def approve
    @grant = authorize Grant.find(params[:grant_id])
    @grant.mark_approved!
    redirect_to grant_process_admin_path(@grant), flash: { success: "Grant approved!" }
  end

  def reject
    @grant = authorize Grant.find(params[:grant_id])
    @grant.mark_rejected!
    redirect_to grant_process_admin_path(@grant), flash: { error: "Grant rejected." }
  end

  def mark_fulfilled
    @grant = authorize Grant.find(params[:grant_id])
    @grant.mark_fulfilled!
    redirect_to grant_process_admin_path(@grant), flash: { success: "Grant marked as fulfilled." }
  end

  def additional_info_needed
    @grant = authorize Grant.find(params[:grant_id])
    @grant.mark_additional_info_needed!
    redirect_to grant_process_admin_path(@grant), flash: { success: 'Grant marked "additional info needed".' }
  end

  def show
    @grant = Grant.find_by_hashid!(params[:id])

    return not_found unless @grant.waiting_on_recipient? || @grant.verifying? || @grant.fulfilled?

    if !signed_in?
      return redirect_to auth_users_path(email: @grant.recipient.email, return_to: grant_path(@grant)), flash: { info: "Please sign in to continue." }
    end

    authorize @grant

  rescue Pundit::NotAuthorizedError
    redirect_to auth_users_path(email: @grant.recipient.email, return_to: grant_path(@grant)), flash: { info: "Please sign in with the same email you received the invitation at." }
  end

  def activate
    @grant = Grant.find_by_hashid!(params[:id])

    return not_found unless @grant.waiting_on_recipient?

    authorize @grant

    grant_params = params.require(:grant).permit(
      :recipient_org_type,
      :receipt_method,
      :recipient_organization,
      :determination_letter,
      :event_id,
      ach_transfer: [
        :recipient_name,
        :routing_number,
        :account_number,
      ],
      increase_check: [
        :address_line1,
        :address_line2,
        :address_city,
        :address_state,
        :address_zip,
      ],
    )

    ActiveRecord::Base.transaction do
      @grant.assign_attributes(grant_params.permit(:recipient_org_type, :receipt_method, :recipient_organization, :determination_letter))

      if @grant.recipient_org_fiscally_sponsored?
        event = EventService::Create.new(
          name: @grant.recipient_organization,
          point_of_contact_id: @grant.event.point_of_contact_id,
          emails: [@grant.recipient.email],
          category: "grant recipient",
          is_public: false,
          is_indexable: false,
          approved: true
        ).run

        @grant.disbursement = DisbursementService::Create.new(
          source_event_id: @grant.event.id,
          destination_event_id: event.id,
          name: "Grant to #{event.name}",
          amount: @grant.amount,
          requested_by_id: nil,
          fulfilled_by_id: nil,
        ).run
        @grant.receipt_method = "disbursement"

        @grant.disbursement.mark_approved!

        @grant.mark_fulfilled!
      elsif @grant.recipient_org_existing_hcb_account?
        event = Event.find(grant_params[:event_id])

        authorize event, :receive_grant?

        @grant.disbursement = DisbursementService::Create.new(
          source_event_id: @grant.event.id,
          destination_event_id: event.id,
          name: "Grant to #{event.name}",
          amount: @grant.amount,
          requested_by_id: nil,
          fulfilled_by_id: nil,
        ).run
        @grant.receipt_method = "disbursement"

        @grant.disbursement.mark_approved!

        @grant.mark_fulfilled!
      elsif @grant.receipt_method_ach_transfer?
        @grant.mark_verifying remove_pending_transaction: true

        @grant.create_ach_transfer!(
          grant_params.require(:ach_transfer).permit(
            :account_number,
            :routing_number,
          ).merge(
            payment_for: "Grant to #{@grant.recipient_organization}",
            event: @grant.event,
            amount: @grant.amount_cents,
            recipient_name: @grant.recipient_organization,
          )
        )
      elsif @grant.receipt_method_check?
        @grant.mark_verifying remove_pending_transaction: true

        @grant.create_increase_check!(
          grant_params.require(:increase_check).permit(
            :address_line1,
            :address_line2,
            :address_city,
            :address_state,
            :address_zip,
          ).merge(
            event: @grant.event,
            amount: @grant.amount_cents,
            recipient_name: @grant.recipient_organization,
            payment_for: "Grant to #{@grant.recipient_organization}",
            memo: "Grant from #{@grant.event.name}",
          )
        )
      else
        @grant.mark_verifying
      end

      @grant.save!
    end

    redirect_back_or_to grant_path(@grant)

  rescue => e
    flash[:error] = e.message
    notify_airbrake(e)
    redirect_back_or_to grant_path(@grant)

  end

  private

  def grant_params
    params.require(:grant).permit(:amount, :reason, :email, :recipient_name, :recipient_organization, :ends_at)
  end

end
