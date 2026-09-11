# frozen_string_literal: true

module Api
  module V5
    class WiresController < ApplicationController
      include Api::V5::ScopedResource

      scoped_resource Wire, organization_scope: :event, preload: [:event]
    end
  end
end
