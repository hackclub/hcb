# frozen_string_literal: true

module Api
  module V5
    class ChecksController < ApplicationController
      include Api::V5::ScopedResource

      scoped_resource IncreaseCheck, organization_scope: :event, preload: [:event]
    end
  end
end
