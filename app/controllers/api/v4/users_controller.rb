# frozen_string_literal: true

module Api
  module V4
    class UsersController < ApplicationController
      skip_after_action :verify_authorized, only: [:available_icons]

      def show
        @user = authorize current_user
      end

      def available_icons
        icons = {
          frc: current_user.events.robotics_team.any?,
          admin: current_user.admin_override_pretend?,
          platinum: current_user.stripe_cards.platinum.any?,
          testflight: Flipper.enabled?(:mobile_testflight_icon, current_user),
          hackathon_grant: current_user
                .events
                .joins(:incoming_disbursements)
                .where("disbursements.source_event_id = ? AND disbursements.aasm_state IN ('pending', 'in_transit', 'deposited')", Event.friendly.find(EventMappingEngine::EventSlugs::HACKATHON_GRANT_FUND).id)
                .any?,
        }



        render json: icons.compact_blank
      end

    end
  end
end
