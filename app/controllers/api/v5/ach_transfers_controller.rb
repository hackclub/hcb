# frozen_string_literal: true

module Api
  module V5
    class AchTransfersController < ApplicationController
      include Api::V5::ScopedResource

      scoped_resource AchTransfer, organization_scope: :event,
                                   preload: [:event, { creator: :organizer_positions }]
    end
  end
end
