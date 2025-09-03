# frozen_string_literal: true

module Api
  module Entities
    class Organization < Base
      when_expanded do
        expose :name
        expose :slug
        expose :website
        expose :category, documentation: {
          values: ["hack_club_hq", "robotics_team", "hackathon", "hack_club", "climate", "nonprofit"]
        } do |organization|
          category = "nonprofit"
          category = "climate" if organization.event_tags.where(name: EventTag::Tags::CLIMATE).exists?
          category = "hack_club" if organization.event_tags.where(name: EventTag::Tags::HACK_CLUB).exists?
          category = "hackathon" if organization.hackathon?
          category = "robotics_team" if organization.robotics_team?
          category = "hack_club_hq" if organization.plan.is_a?(Event::Plan::HackClubAffiliate)

          category
        end
        expose :is_public, as: :transparent, documentation: { type: "boolean" }
        expose :demo_mode, documentation: { type: "boolean" }
        expose :logo do |organization|
          url_for_attached organization.logo
        end
        expose :donation_header do |organization|
          url_for_attached organization.donation_header_image
        end
        expose :background_image do |organization|
          url_for_attached organization.background_image
        end
        expose :public_message do |organization|
          organization.public_message.presence
        end
        expose :donation_link do |organization|
          if organization.donation_page_available?
            Rails.application.routes.url_helpers.start_donation_donations_url(organization)
          else
            nil
          end
        end
        expose :balances do
          expose :balance_available_v2_cents, as: :balance_cents, documentation: { type: "integer" }
          expose :fee_balance_v2_cents, as: :fee_balance_cents, documentation: { type: "integer" }
          expose :pending_incoming_balance_v2_cents, as: :incoming_balance_cents, documentation: { type: "integer" }
          expose :total_raised, as: :total_raised, documentation: { type: "integer" }
        end

        format_as_date do
          expose :created_at
        end

        # This association is intentionally nested within the `when_expanded`.
        # This means that users will only be visible when an Organization is
        # expanded.
        expose_associated User, as: "users", documentation: { type: User, is_array: true } do |event, options|
          event.users
        end
      end

    end
  end
end
