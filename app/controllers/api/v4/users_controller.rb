# frozen_string_literal: true

module Api
  module V4
    class UsersController < ApplicationController
      skip_after_action :verify_authorized, only: [:available_icons, :beacon_config, :revoke]
      before_action :require_admin!, only: [:show, :by_email]
      before_action :require_trusted_oauth_app!, only: [:beacon_config]

      def me
        @user = authorize current_user, :show?
        render :show
      end

      def revoke
        @current_token.update(revoked_at: Time.now)
        render json: {
          success: true,
          owner_email: current_user.email,
          key_name: @current_token.application&.name
        }
      end

      def show
        @user = User.find_by_public_id!(params[:id])
        authorize @user
      end

      def by_email
        @user = User.find_by!(email: params[:email])
        authorize @user, :show?
        render :show
      end

      require_oauth2_scope "user_lookup", :show, :by_email

      def available_icons
        icons = {
          frc: current_user.events.robotics_team.any?,
          admin: current_user.admin_override_pretend?,
          platinum: current_user.stripe_cards.platinum.any?,
          testflight: Flipper.enabled?(:mobile_testflight_icon, current_user),
          hackathon_grant: current_user
                .events
                .joins(:incoming_disbursements)
                .where("disbursements.source_event_id = ? AND disbursements.aasm_state IN ('pending', 'in_transit', 'deposited')", EventMappingEngine::EventIds::HACKATHON_GRANT_FUND)
                .any?,
          premium: current_user.events.any? { |e| e.users.where(teenager: true).active.size >= 10 }
        }



        render json: icons.compact_blank
      end

      def beacon_config
        render json: {
          signature: OpenSSL::HMAC.hexdigest("sha256", Credentials.fetch(:HELPSCOUT, :BEACON_SECRET_KEY), current_user.email)
        }
      end

    end
  end
end
