# frozen_string_literal: true

module Api
  module V4
    class CardGrantsController < ApplicationController
      def index
        if params[:event_id].present?
          @event = authorize(Event.find_by_public_id(params[:event_id]) || Event.friendly.find(params[:event_id]), :transfers?)
          @card_grants = @event.card_grants.includes(:user, :event).order(created_at: :desc)
        else
          skip_authorization
          @card_grants = current_user.card_grants.includes(:user, :event).order(created_at: :desc)
        end
      end

      def create
        @event = Event.find_by_public_id(params[:event_id]) || Event.friendly.find(params[:event_id])

        @card_grant = @event.card_grants.build(params.permit(:amount_cents, :email, :merchant_lock, :category_lock, :keyword_lock, :purpose, :one_time_use, :pre_authorization_required, :instructions).merge(sent_by: current_user))

        authorize @card_grant

        begin
          # There's no way to save a card grant without potentially triggering an
          # exception as under the hood it calls `DisbursementService::Create` and a
          # number of other methods (e.g. `save!`) which either succeed or raise.
          @card_grant.save!
        rescue => e
          messages = []

          case e
          when ActiveRecord::RecordInvalid
            # We expect to encounter validation errors from `CardGrant`, but anything
            # else is the result of downstream logic which shouldn't fail.
            raise e unless e.record.is_a?(CardGrant)

            messages.concat(@card_grant.errors.full_messages)
          when DisbursementService::Create::UserError
            messages << e.message
          else
            raise e
          end

          render(
            json: { error: "invalid_operation", messages: },
            status: :unprocessable_entity
          )
          return
        end

        render(
          status: :created,
          location: api_v4_card_grant_path(@card_grant)
        )
      end

      def show
        @card_grant = CardGrant.find_by_public_id!(params[:id])

        authorize @card_grant
      end

      def topup
        @card_grant = CardGrant.find_by_public_id!(params[:id])

        authorize @card_grant
        begin
          @card_grant.topup!(amount_cents: params["amount_cents"], topped_up_by: current_user)
        rescue ArgumentError => e
          return render json: { error: "invalid_operation", messages: [e.message] }, status: :bad_request
        end
      end

      def update
        @card_grant = CardGrant.find_by_public_id!(params[:id])

        authorize @card_grant

        @card_grant.update!(params.permit(:merchant_lock, :category_lock, :keyword_lock, :purpose, :one_time_use, :instructions))

        render :show
      end

      def cancel
        @card_grant = CardGrant.find_by_public_id!(params[:id])

        authorize @card_grant

        begin
          @card_grant.cancel!(current_user)
        rescue ArgumentError => e
          return render json: { error: "invalid_operation", messages: [e.message] }, status: :bad_request
        end

        render :show
      end

    end
  end
end
