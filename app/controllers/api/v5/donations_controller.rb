# frozen_string_literal: true

module Api
  module V5
    class DonationsController < ApplicationController
      include Api::V5::ScopedResource

      scoped_resource Donation, organization_scope: :event, preload: [:event]
    end
  end
end
