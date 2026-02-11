# frozen_string_literal: true

module Api
  module V4
    class CardGrantsController < ApplicationController
      include SetEvent
      include ApplicationHelper

      before_action :set_api_event, only: [:create]
      before_action :set_card_grant, except: [:index, :create]

      def index
        if params[:event_id].present?
          set_api_event
          authorize @event, :transfers_in_v4?
          @card_grants = @event.card_grants.includes(:user, :event).order(created_at: :desc)
        else
          skip_authorization
          @card_grants = current_user.card_grants.includes(:user, :event).order(created_at: :desc)
        end
      end

      def create
        sent_by = current_user

        if current_user.admin? && params.key?(:sent_by_email)
          found_user = User.find_by(email: params[:sent_by_email])

          if found_user.nil?
            skip_authorization
            return render json: { error: "invalid_user", messages: "User with email '#{params[:sent_by_email]}' not found" }, status: :bad_request
          end

          sent_by = found_user
        end

        expiration_at = params["expiration_at"].to_datetime

        @card_grant = @event.card_grants.build(params.permit(:amount_cents, :email, :invite_message, :merchant_lock, :category_lock, :keyword_lock, :purpose, :one_time_use, :pre_authorization_required, :instructions).merge(sent_by:, expiration_at:))

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

        render :create, status: :created, location: api_v4_card_grant_path(@card_grant)
      end

      require_oauth2_scope "card_grants:write", :create

      def show
        authorize @card_grant
      end

      def topup
        authorize @card_grant

        @card_grant.topup!(amount_cents: params["amount_cents"], topped_up_by: current_user)
      end

      def withdraw
        authorize @card_grant

        @card_grant.withdraw!(amount_cents: params["amount_cents"], withdrawn_by: current_user)
      end

      def update
        authorize @card_grant

        @card_grant.update!(params.permit(:merchant_lock, :category_lock, :keyword_lock, :purpose, :one_time_use, :instructions))

        render :show
      end

      def cancel
        authorize @card_grant

        @card_grant.cancel!(current_user)
        render :show
      end

      def activate
        authorize @card_grant

        @card_grant.create_stripe_card(request.remote_ip)
        render :show
      end

      def transactions
        authorize @card_grant

        @hcb_codes = @card_grant.visible_hcb_codes

        @total_count = @hcb_codes.size
        @hcb_codes = paginate_hcb_codes(@hcb_codes)
      end

      private

      def set_card_grant
        @card_grant = CardGrant.find_by_public_id!(params[:id])
      end

    end
  end
end
