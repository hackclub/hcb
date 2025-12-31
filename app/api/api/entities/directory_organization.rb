# frozen_string_literal: true

module Api
  module Entities
    class DirectoryOrganization < Api::Entities::Base
      def self.is_transparent?
        ->(org, _) { org.is_public? }
      end

      def self.partner_128_collective_org?
        ->(org, _) do
          # This is written with filtering in Ruby rather than SQL to use
          # previously loaded data and prevent an N+1.
          org.event_tags.any? do |tag|
            tag.name == EventTag::Tags::CLIMATE && tag.purpose == "directory"
          end
        end
      end

      expose :name
      expose :description

      expose :slug, if: is_transparent?
      expose :website
      expose :is_public, as: :transparent
      expose :location do
        expose :country, as: :country_code
        expose :country do |organization|
          ISO3166::Country.new(organization.country)&.common_name
        end
        expose :continent do |organization|
          continent = ISO3166::Country.new(organization.country)&.continent
          # https://github.com/countries/countries/issues/700
          case continent
          when "Australia"
            "Oceania"
          else
            continent
          end
        end
      end

      expose :category do |organization|
        category = "nonprofit"
        category = "climate" if organization.event_tags.where(name: EventTag::Tags::CLIMATE).exists?
        category = "hack_club" if organization.event_tags.where(name: EventTag::Tags::HACK_CLUB).exists?
        category = "hackathon" if organization.hackathon?
        category = "robotics_team" if organization.robotics_team?
        category = "hack_club_hq" if organization.plan.is_a?(Event::Plan::HackClubAffiliate)

        category
      end
      expose :missions do |organization|
        # This is written with filtering in Ruby rather than SQL to use
        # previously loaded data and prevent an N+1.
        organization.event_tags
                    .select { |tag| tag.purpose == :mission }
                    .map { |tag| tag.api_name(:short) }
      end
      expose :climate do |organization|
        self.class.partner_128_collective_org?.call(organization, nil)
      end

      expose :partners do
        expose :"128_collective", if: partner_128_collective_org? do
          expose :funded do |organization|
            organization.event_tags.any? { |tag| tag.name == EventTag::Tags::PARTNER_128_COLLECTIVE_FUNDED }
          end

          expose :recommended do |organization|
            organization.event_tags.any? { |tag| tag.name == EventTag::Tags::PARTNER_128_COLLECTIVE_RECOMMENDED }
          end
        end
      end

      expose :logo do |organization|
        if organization.logo.attached? && organization.logo.variable?
          Rails.application.routes.url_helpers.url_for(
            organization.logo.variant(resize_to_limit: [200, 200], saver: { quality: 80 })
          )
        elsif organization.logo.attached?
          url_for_attached organization.logo
        end
      end
      expose :background_image do |organization|
        if organization.background_image.attached? && organization.background_image.variable?
          Rails.application.routes.url_helpers.url_for(
            organization.background_image.variant(resize_to_limit: [800, 800], saver: { quality: 80 })
          )
        else
          url_for_attached organization.background_image
        end
      end
      expose :donation_link do |organization|
        if organization.donation_page_available?
          Rails.application.routes.url_helpers.start_donation_donations_url(organization)
        else
          nil
        end
      end

      unexpose :href

    end
  end
end
