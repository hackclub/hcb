# frozen_string_literal: true

module Api
  module V5
    class WiseTransfersController < ApplicationController
      include Api::V5::ScopedResource

      scoped_resource WiseTransfer, organization_scope: :event, preload: [:event]
    end
  end
end
