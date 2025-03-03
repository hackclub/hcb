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

        @card_grant = @event.card_grants.build(params.permit(:amount_cents, :email, :merchant_lock, :category_lock, :keyword_lock, :purpose).merge(sent_by: current_user))

        authorize @card_grant

        @card_grant.save!
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

        @card_grant.update!(params.permit(:merchant_lock, :category_lock, :keyword_lock, :purpose))

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
