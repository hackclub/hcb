# frozen_string_literal: true

module Api
  module V5
    class CheckDepositsController < ApplicationController
      include Api::V5::ScopedResource

      scoped_resource CheckDeposit, organization_scope: :event, preload: [:event]
    end
  end
end
