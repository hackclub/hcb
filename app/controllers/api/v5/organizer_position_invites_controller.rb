# frozen_string_literal: true

module Api
  module V5
    class OrganizerPositionInvitesController < ApplicationController
      include Api::V5::ScopedResource

      scoped_resource OrganizerPositionInvite, organization_scope: :event,
                                               preload: [:event, :user, :sender]

      require_oauth2_scope "invitations:read", :index, :show
    end
  end
end
