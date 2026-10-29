# frozen_string_literal: true

module Api
  module V4
    module StripeCards
      class PersonalizationDesignsController < ApplicationController
        include SetEvent

        def index
          if params[:event_id].present?
            set_api_event
            authorize @event, :create_stripe_card?, policy_class: ::EventPolicy

            @designs = [@event.stripe_card_personalization_designs&.available, StripeCard::PersonalizationDesign.common.available].flatten.compact
          else
            skip_authorization
            @designs = StripeCard::PersonalizationDesign.common.available
          end

          @designs += StripeCard::PersonalizationDesign.unlisted.available if can_admin?(:read)
        end

      end
    end
  end
end
