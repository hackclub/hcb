# frozen_string_literal: true

module ApiService
  module V2
    class PartneredSignupsNew
      def initialize(partner_id:,
                     organization_identifier:, redirect_url:, webhook_url:)
        @partner_id = partner_id
        @organization_identifier = organization_identifier
        @redirect_url = redirect_url
        @webhook_url = webhook_url
      end

      def run
        if existing_event
          existing_event.redirect_url = @redirect_url
          existing_event.webhook_url = @webhook_url
          existing_event.save!
          existing_event.reload
        else
          ::Event.create!(attrs)
        end
      end

      private

      def existing_event
        @existing_event ||= partner.events.find_by(organization_identifier: clean_organization_identifier)
      end

      def attrs
        {
          partner:,
          organization_identifier: clean_organization_identifier,
          name: smart_name,
          slug: smart_slug,
          redirect_url: @redirect_url,
          webhook_url: @webhook_url
        }
      end

      def smart_name
        @organization_identifier
      end

      def smart_slug
        @smart_slug ||= begin
          count = ::Event.where(slug: @organization_identifier).count

          return "#{@organization_identifier}#{count + 1}" if count > 0

          @organization_identifier
        end
      end

      def sponsorship_fee
        0.10 # 10% percent
      end

      def partner
        @partner ||= Partner.find(@partner_id)
      end

      def clean_organization_identifier
        @organization_identifier.to_s.strip
      end

    end
  end
end
