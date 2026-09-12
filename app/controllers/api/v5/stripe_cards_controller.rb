# frozen_string_literal: true

module Api
  module V5
    class StripeCardsController < ApplicationController
      include Api::V5::ScopedResource

      scoped_resource StripeCard, organization_scope: :event,
                                  preload: [:event, :user, :stripe_cardholder]

      require_oauth2_scope "cards:read", :index, :show
    end
  end
end
