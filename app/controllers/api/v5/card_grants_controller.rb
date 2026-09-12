# frozen_string_literal: true

module Api
  module V5
    class CardGrantsController < ApplicationController
      include Api::V5::ScopedResource

      scoped_resource CardGrant, organization_scope: :event, preload: [:event, :user, :stripe_card]

      require_oauth2_scope "card_grants:read", :index, :show
    end
  end
end
